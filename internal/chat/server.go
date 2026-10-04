package chat

import (
	"bufio"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"os"
	"strings"
	"sync"
	"syscall"
	"time"
)

const (
	maxMessageLength = 4096
	maxLineLength    = 8192
)

// Request representa un mensaje enviado por un cliente.
type Request struct {
	Type      string `json:"type"`
	User      string `json:"user"`
	Text      string `json:"text"`
	Timestamp int64  `json:"timestamp,omitempty"`
}

// Event representa información enviada por el servidor.
type Event struct {
	Type      string    `json:"type"`
	ID        uint64    `json:"id,omitempty"`
	User      string    `json:"user,omitempty"`
	Text      string    `json:"text,omitempty"`
	Time      time.Time `json:"time,omitempty"`
	Timestamp int64     `json:"timestamp,omitempty"`

	CPUPercent     float64 `json:"cpu_percent,omitempty"`
	MemoryBytes    uint64  `json:"memory_bytes,omitempty"`
	ConnectedUsers int     `json:"connected_users,omitempty"`
}

// Server contiene el estado del servidor.
type Server struct {
	mu      sync.Mutex
	history []Event
	clients map[*client]struct{}
	file    *os.File
	nextID  uint64

	metricsMu       sync.Mutex
	lastCPUTime     time.Duration
	lastCPUSampleAt time.Time
}

// client representa una conexión TCP.
type client struct {
	conn net.Conn
	user string
	mu   sync.Mutex
}

// New crea el servidor y carga el historial.
func New(historyPath string) (*Server, error) {
	file, err := os.OpenFile(
		historyPath,
		os.O_CREATE|os.O_APPEND|os.O_RDWR,
		0o600,
	)

	if err != nil {
		return nil, fmt.Errorf(
			"open history: %w",
			err,
		)
	}

	server := &Server{
		clients: make(map[*client]struct{}),
		file:    file,
	}

	if err := server.loadHistory(file); err != nil {
		_ = file.Close()
		return nil, err
	}

	return server, nil
}

// Close cierra las conexiones activas.
func (s *Server) Close() error {
	s.mu.Lock()
	defer s.mu.Unlock()

	for client := range s.clients {
		_ = client.conn.Close()
	}

	return s.file.Close()
}

// ServeConn atiende una conexión TCP.
func (s *Server) ServeConn(conn net.Conn) {
	client := &client{
		conn: conn,
	}

	defer conn.Close()

	if err := s.register(client); err != nil {
		return
	}

	defer s.unregister(client)

	scanner :=
		bufio.NewScanner(conn)

	scanner.Buffer(
		make([]byte, 1024),
		maxLineLength,
	)

	for scanner.Scan() {
		var request Request

		if err := json.Unmarshal(
			scanner.Bytes(),
			&request,
		); err != nil {

			s.send(
				client,
				Event{
					Type: "error",
					Text: "invalid JSON",
				},
			)

			continue
		}

		user :=
			strings.TrimSpace(
				request.User,
			)

		if user == "" {
			s.send(
				client,
				Event{
					Type: "error",
					Text: "a user is required",
				},
			)

			continue
		}

		switch request.Type {

		case "ping":
			cpuPercent,
				memoryBytes,
				connectedUsers :=
				s.processMetrics()

			s.send(
				client,
				Event{
					Type:           "pong",
					Timestamp:      request.Timestamp,
					CPUPercent:     cpuPercent,
					MemoryBytes:    memoryBytes,
					ConnectedUsers: connectedUsers,
				},
			)

		case "join":
			s.mu.Lock()

			alreadyJoined :=
				client.user != ""

			client.user =
				user

			s.mu.Unlock()

			if !alreadyJoined {
				s.publish(
					"Sistema",
					fmt.Sprintf(
						"%s se ha unido al chat",
						user,
					),
				)
			}

		case "message":
			text :=
				strings.TrimSpace(
					request.Text,
				)

			if text == "" {
				s.send(
					client,
					Event{
						Type: "error",
						Text: "a message requires text",
					},
				)

				continue
			}

			if len([]rune(text)) >
				maxMessageLength {

				s.send(
					client,
					Event{
						Type: "error",
						Text: "message exceeds the maximum length",
					},
				)

				continue
			}

			s.mu.Lock()

			if client.user == "" {
				client.user =
					user
			}

			s.mu.Unlock()

			s.publish(
				user,
				text,
			)

		default:
			s.send(
				client,
				Event{
					Type: "error",
					Text: "invalid request type",
				},
			)
		}
	}
}

// ============================================================
// MÉTRICAS
// ============================================================

func (s *Server) processMetrics() (
	float64,
	uint64,
	int,
) {
	s.metricsMu.Lock()
	defer s.metricsMu.Unlock()

	now :=
		time.Now()

	// ---------------------------------------------------------
	// CPU
	// ---------------------------------------------------------

	var usage syscall.Rusage
	var cpuPercent float64

	err :=
		syscall.Getrusage(
			syscall.RUSAGE_SELF,
			&usage,
		)

	if err == nil {
		userCPU :=
			time.Duration(
				usage.Utime.Sec,
			)*time.Second +
				time.Duration(
					usage.Utime.Usec,
				)*time.Microsecond

		systemCPU :=
			time.Duration(
				usage.Stime.Sec,
			)*time.Second +
				time.Duration(
					usage.Stime.Usec,
				)*time.Microsecond

		currentCPU :=
			userCPU +
				systemCPU

		if !s.lastCPUSampleAt.IsZero() {
			wallElapsed :=
				now.Sub(
					s.lastCPUSampleAt,
				)

			cpuElapsed :=
				currentCPU -
					s.lastCPUTime

			if wallElapsed > 0 {
				cpuPercent =
					float64(cpuElapsed) /
						float64(wallElapsed) *
						100.0
			}
		}

		s.lastCPUTime =
			currentCPU

		s.lastCPUSampleAt =
			now
	}

	// ---------------------------------------------------------
	// MEMORIA
	// ---------------------------------------------------------

	var memoryBytes uint64

	data, err :=
		os.ReadFile(
			"/proc/self/statm",
		)

	if err == nil {
		var totalPages uint64
		var residentPages uint64

		_, err :=
			fmt.Sscanf(
				string(data),
				"%d %d",
				&totalPages,
				&residentPages,
			)

		if err == nil {
			memoryBytes =
				residentPages *
					uint64(
						os.Getpagesize(),
					)
		}
	}

	// ---------------------------------------------------------
	// USUARIOS CONECTADOS
	// ---------------------------------------------------------

	s.mu.Lock()

	connectedUsers :=
		0

	for client := range s.clients {

		if client.user != "" {
			connectedUsers++
		}
	}

	s.mu.Unlock()

	return cpuPercent,
		memoryBytes,
		connectedUsers
}

// ============================================================
// HISTORIAL
// ============================================================

func (s *Server) loadHistory(
	file *os.File,
) error {

	scanner :=
		bufio.NewScanner(file)

	scanner.Buffer(
		make([]byte, 1024),
		maxLineLength,
	)

	for scanner.Scan() {
		var event Event

		if err := json.Unmarshal(
			scanner.Bytes(),
			&event,
		); err != nil ||
			event.Type != "message" {

			return fmt.Errorf(
				"read history: invalid record",
			)
		}

		s.history =
			append(
				s.history,
				event,
			)

		if event.ID >
			s.nextID {

			s.nextID =
				event.ID
		}
	}

	if err := scanner.Err(); err != nil {
		return fmt.Errorf(
			"read history: %w",
			err,
		)
	}

	_, err :=
		file.Seek(
			0,
			io.SeekEnd,
		)

	return err
}

// ============================================================
// REGISTRO
// ============================================================

func (s *Server) register(
	client *client,
) error {

	s.mu.Lock()
	defer s.mu.Unlock()

	for _, event := range s.history {

		if err :=
			s.sendLocked(
				client,
				event,
			); err != nil {

			return err
		}
	}

	s.clients[client] =
		struct{}{}

	return nil
}

// ============================================================
// DESREGISTRO
// ============================================================

func (s *Server) unregister(
	client *client,
) {

	s.mu.Lock()

	userName :=
		client.user

	delete(
		s.clients,
		client,
	)

	s.mu.Unlock()

	if userName != "" {
		s.publish(
			"Sistema",
			fmt.Sprintf(
				"%s se ha desconectado",
				userName,
			),
		)
	}
}

// ============================================================
// PUBLICACIÓN
// ============================================================

func (s *Server) publish(
	user string,
	text string,
) {

	s.mu.Lock()
	defer s.mu.Unlock()

	s.nextID++

	event := Event{
		Type: "message",
		ID:   s.nextID,
		User: user,
		Text: text,
		Time: time.Now().Local(),
	}

	record, err :=
		json.Marshal(event)

	if err != nil {
		return
	}

	if _, err :=
		s.file.Write(
			append(
				record,
				'\n',
			),
		); err != nil {

		return
	}

	s.history =
		append(
			s.history,
			event,
		)

	for client := range s.clients {

		if err :=
			s.sendLocked(
				client,
				event,
			); err != nil {

			_ =
				client.conn.Close()

			delete(
				s.clients,
				client,
			)
		}
	}
}

// ============================================================
// ENVÍO
// ============================================================

func (s *Server) send(
	client *client,
	event Event,
) {

	client.mu.Lock()
	defer client.mu.Unlock()

	_ =
		writeEvent(
			client.conn,
			event,
		)
}

func (s *Server) sendLocked(
	client *client,
	event Event,
) error {

	client.mu.Lock()
	defer client.mu.Unlock()

	return writeEvent(
		client.conn,
		event,
	)
}

// ============================================================
// JSON
// ============================================================

func writeEvent(
	writer io.Writer,
	event Event,
) error {

	encoder :=
		json.NewEncoder(
			writer,
		)

	return encoder.Encode(
		event,
	)
}

var ErrInvalidMessage = errors.New(
	"invalid message",
)
