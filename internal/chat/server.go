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
	"time"
)

const (
	maxMessageLength = 4096
	maxLineLength    = 8192
)

type Request struct {
	Type string `json:"type"`
	User string `json:"user"`
	Text string `json:"text"`
}

type Event struct {
	Type string    `json:"type"`
	ID   uint64    `json:"id,omitempty"`
	User string    `json:"user,omitempty"`
	Text string    `json:"text,omitempty"`
	Time time.Time `json:"time,omitempty"`
}

type Server struct {
	mu      sync.Mutex
	history []Event
	clients map[*client]struct{}
	file    *os.File
	nextID  uint64
}

type client struct {
	conn net.Conn
	mu   sync.Mutex
}

func New(historyPath string) (*Server, error) {
	file, err := os.OpenFile(historyPath, os.O_CREATE|os.O_APPEND|os.O_RDWR, 0o600)
	if err != nil {
		return nil, fmt.Errorf("open history: %w", err)
	}

	server := &Server{
		clients: make(map[*client]struct{}),
		file:    file,
	}
	if err := server.loadHistory(file); err != nil {
		file.Close()
		return nil, err
	}
	return server, nil
}

func (s *Server) Close() error {
	s.mu.Lock()
	defer s.mu.Unlock()
	for client := range s.clients {
		_ = client.conn.Close()
	}
	return s.file.Close()
}

func (s *Server) ServeConn(conn net.Conn) {
	client := &client{conn: conn}
	defer conn.Close()

	if err := s.register(client); err != nil {
		return
	}
	defer s.unregister(client)

	scanner := bufio.NewScanner(conn)
	scanner.Buffer(make([]byte, 1024), maxLineLength)
	for scanner.Scan() {
		var request Request
		if err := json.Unmarshal(scanner.Bytes(), &request); err != nil {
			s.send(client, Event{Type: "error", Text: "invalid JSON"})
			continue
		}
		if request.Type != "message" || strings.TrimSpace(request.User) == "" || strings.TrimSpace(request.Text) == "" {
			s.send(client, Event{Type: "error", Text: "a message requires type, user and text"})
			continue
		}
		if len([]rune(request.Text)) > maxMessageLength {
			s.send(client, Event{Type: "error", Text: "message exceeds the maximum length"})
			continue
		}
		s.publish(request.User, request.Text)
	}
}

func (s *Server) loadHistory(file *os.File) error {
	scanner := bufio.NewScanner(file)
	scanner.Buffer(make([]byte, 1024), maxLineLength)
	for scanner.Scan() {
		var event Event
		if err := json.Unmarshal(scanner.Bytes(), &event); err != nil || event.Type != "message" {
			return fmt.Errorf("read history: invalid record")
		}
		s.history = append(s.history, event)
		if event.ID > s.nextID {
			s.nextID = event.ID
		}
	}
	if err := scanner.Err(); err != nil {
		return fmt.Errorf("read history: %w", err)
	}
	_, err := file.Seek(0, io.SeekEnd)
	return err
}

func (s *Server) register(client *client) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	for _, event := range s.history {
		if err := s.sendLocked(client, event); err != nil {
			return err
		}
	}
	s.clients[client] = struct{}{}
	return nil
}

func (s *Server) unregister(client *client) {
	s.mu.Lock()
	delete(s.clients, client)
	s.mu.Unlock()
}

func (s *Server) publish(user, text string) {
	s.mu.Lock()
	defer s.mu.Unlock()

	s.nextID++
	event := Event{Type: "message", ID: s.nextID, User: user, Text: text, Time: time.Now().UTC()}
	record, err := json.Marshal(event)
	if err != nil {
		return
	}
	if _, err := s.file.Write(append(record, '\n')); err != nil {
		return
	}
	s.history = append(s.history, event)
	for client := range s.clients {
		if err := s.sendLocked(client, event); err != nil {
			_ = client.conn.Close()
			delete(s.clients, client)
		}
	}
}

func (s *Server) send(client *client, event Event) {
	client.mu.Lock()
	defer client.mu.Unlock()
	_ = writeEvent(client.conn, event)
}

func (s *Server) sendLocked(client *client, event Event) error {
	client.mu.Lock()
	defer client.mu.Unlock()
	return writeEvent(client.conn, event)
}

func writeEvent(writer io.Writer, event Event) error {
	encoder := json.NewEncoder(writer)
	return encoder.Encode(event)
}

var ErrInvalidMessage = errors.New("invalid message")
