package chat

import (
	// Scanner permite leer la conexión cliente por cliente, una línea JSON a la vez.
	"bufio"
	// encoding/json serializa y deserializa las solicitudes y eventos del protocolo.
	"encoding/json"
	// errors permite declarar errores reutilizables del paquete.
	"errors"
	// fmt construye mensajes de error y avisos del sistema.
	"fmt"
	// io proporciona interfaces y operaciones de entrada/salida.
	"io"
	// net contiene las abstracciones de conexiones TCP.
	"net"
	// os permite abrir, escribir y cerrar el archivo del historial.
	"os"
	// strings se usa para quitar espacios y validar textos vacíos.
	"strings"
	// sync proporciona mutexes para proteger los datos compartidos.
	"sync"
	// time registra la fecha y hora de cada evento.
	"time"
)

const (
	// Límite máximo de caracteres permitidos en el texto de un mensaje.
	maxMessageLength = 4096
	// Límite máximo de bytes que puede ocupar una línea recibida.
	// Incluye el JSON completo, no solo el texto del mensaje.
	maxLineLength = 8192
)

// Request representa un mensaje que envía un cliente al servidor.
// El cliente debe enviar una línea JSON por cada solicitud.
type Request struct {
	Type string `json:"type"` // "join" para identificarse o "message" para enviar texto.
	User string `json:"user"` // Nombre del usuario que realiza la solicitud.
	Text string `json:"text"` // Contenido del mensaje cuando Type es "message".
}

// Event representa cualquier información que el servidor envía a un cliente.
// Actualmente se usa para mensajes del chat y respuestas de error.
type Event struct {
	Type string    `json:"type"`           // Tipo de evento: "message" o "error".
	ID   uint64    `json:"id,omitempty"`   // Identificador incremental del mensaje.
	User string    `json:"user,omitempty"` // Usuario que originó el evento.
	Text string    `json:"text,omitempty"` // Texto del mensaje o descripción del error.
	Time time.Time `json:"time,omitempty"` // Fecha y hora en la zona local del servidor.
}

// Server contiene el estado completo del chat.
type Server struct {
	mu      sync.Mutex           // Protege history, clients y nextID.
	history []Event              // Historial cargado desde el archivo y mensajes nuevos.
	clients map[*client]struct{} // Conjunto de clientes actualmente conectados.
	file    *os.File             // Archivo JSONL donde se persisten los eventos.
	nextID  uint64               // Próximo identificador disponible para un mensaje.
}

// client agrupa la conexión TCP y los datos propios de un cliente.
type client struct {
	conn net.Conn   // Conexión TCP con el dispositivo cliente.
	user string     // Nombre del usuario identificado en esta conexión.
	mu   sync.Mutex // Evita escrituras simultáneas sobre la conexión.
}

// New crea un servidor y carga el historial existente desde historyPath.
func New(historyPath string) (*Server, error) {
	// O_CREATE crea el archivo si no existe; O_APPEND agrega registros al final;
	// O_RDWR permite leer el historial y después escribir nuevos eventos.
	file, err := os.OpenFile(historyPath, os.O_CREATE|os.O_APPEND|os.O_RDWR, 0o600)
	if err != nil {
		return nil, fmt.Errorf("open history: %w", err)
	}

	server := &Server{
		clients: make(map[*client]struct{}),
		file:    file,
	}
	// loadHistory también actualiza nextID para no reutilizar identificadores.
	if err := server.loadHistory(file); err != nil {
		_ = file.Close()
		return nil, err
	}
	return server, nil
}

// Close cierra las conexiones activas y el archivo del historial.
func (s *Server) Close() error {
	s.mu.Lock()
	defer s.mu.Unlock()
	for client := range s.clients {
		// Cerrar la conexión provoca que el cliente deje de leer del servidor.
		_ = client.conn.Close()
	}
	return s.file.Close()
}

// ServeConn atiende una conexión TCP hasta que el cliente se desconecta.
func (s *Server) ServeConn(conn net.Conn) {
	// Se crea el estado del cliente asociado a esta conexión.
	client := &client{conn: conn}
	// La conexión siempre se cierra al terminar esta función.
	defer conn.Close()

	// Primero se envía el historial al nuevo cliente y se registra en clients.
	if err := s.register(client); err != nil {
		return
	}
	// Se elimina el cliente y se notifica su salida al desconectarse.
	defer s.unregister(client)

	// Scanner separa la entrada por saltos de línea.
	// Por lo tanto, cada solicitud debe ser un objeto JSON en una sola línea.
	scanner := bufio.NewScanner(conn)
	scanner.Buffer(make([]byte, 1024), maxLineLength)
	for scanner.Scan() {
		var request Request
		// Se convierte la línea recibida desde JSON a Request.
		if err := json.Unmarshal(scanner.Bytes(), &request); err != nil {
			s.send(client, Event{Type: "error", Text: "invalid JSON"})
			continue
		}

		// El nombre es obligatorio para ambos tipos de solicitud.
		user := strings.TrimSpace(request.User)
		if user == "" {
			s.send(client, Event{Type: "error", Text: "a user is required"})
			continue
		}

		switch request.Type {
		case "join":
			// join identifica la conexión con un usuario.
			s.mu.Lock()
			alreadyJoined := (client.user != "")
			client.user = user
			s.mu.Unlock()

			// Solo se anuncia la primera identificación de esta conexión.
			if !alreadyJoined {
				s.publish("Sistema", fmt.Sprintf("%s se ha unido al chat", user))
			}

		case "message":
			// Se eliminan espacios externos y se rechazan mensajes vacíos.
			text := strings.TrimSpace(request.Text)
			if text == "" {
				s.send(client, Event{Type: "error", Text: "a message requires text"})
				continue
			}
			// Se cuentan caracteres Unicode, no bytes, para que el límite sea
			// correcto también con tildes, emojis y otros caracteres multibyte.
			if len([]rune(text)) > maxMessageLength {
				s.send(client, Event{Type: "error", Text: "message exceeds the maximum length"})
				continue
			}

			// Si el cliente no envió join, se identifica automáticamente
			// usando el usuario incluido en su primer mensaje.
			s.mu.Lock()
			if client.user == "" {
				client.user = user
			}
			s.mu.Unlock()

			s.publish(user, text)

		default:
			// Se rechazan tipos de solicitud que el protocolo no conoce.
			s.send(client, Event{Type: "error", Text: "invalid request type"})
		}
	}
}

// loadHistory lee todos los eventos guardados en el archivo JSONL.
func (s *Server) loadHistory(file *os.File) error {
	scanner := bufio.NewScanner(file)
	scanner.Buffer(make([]byte, 1024), maxLineLength)
	for scanner.Scan() {
		var event Event
		// Cada línea debe ser un evento de tipo message válido.
		if err := json.Unmarshal(scanner.Bytes(), &event); err != nil || event.Type != "message" {
			return fmt.Errorf("read history: invalid record")
		}
		s.history = append(s.history, event)
		// Se conserva el mayor ID para continuar la numeración correctamente.
		if event.ID > s.nextID {
			s.nextID = event.ID
		}
	}
	if err := scanner.Err(); err != nil {
		return fmt.Errorf("read history: %w", err)
	}
	// El archivo se leyó desde el inicio; se mueve el cursor al final para
	// que las escrituras posteriores se agreguen correctamente.
	_, err := file.Seek(0, io.SeekEnd)
	return err
}

// register envía el historial y agrega un cliente al conjunto de conectados.
func (s *Server) register(client *client) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	for _, event := range s.history {
		// Se usa sendLocked porque el mutex principal ya está tomado.
		if err := s.sendLocked(client, event); err != nil {
			return err
		}
	}
	s.clients[client] = struct{}{}
	return nil
}

// unregister quita un cliente y anuncia su desconexión si ya se había
// identificado con un nombre.
func (s *Server) unregister(client *client) {
	s.mu.Lock()
	userName := client.user
	delete(s.clients, client)
	s.mu.Unlock()

	// Notificar salida si el usuario estuvo identificado
	if userName != "" {
		s.publish("Sistema", fmt.Sprintf("%s se ha desconectado", userName))
	}
}

// publish crea, guarda y distribuye un nuevo evento a todos los clientes.
func (s *Server) publish(user, text string) {
	s.mu.Lock()
	defer s.mu.Unlock()

	// Cada evento recibe un ID único dentro de este servidor.
	s.nextID++
	event := Event{Type: "message", ID: s.nextID, User: user, Text: text, Time: time.Now().Local()}
	// Se serializa una sola vez para persistir el registro en JSONL.
	record, err := json.Marshal(event)
	if err != nil {
		return
	}
	// Se agrega un salto de línea para que el siguiente evento quede en otra línea.
	if _, err := s.file.Write(append(record, '\n')); err != nil {
		return
	}
	s.history = append(s.history, event)
	for client := range s.clients {
		// Un error de escritura indica que el cliente probablemente se desconectó.
		// Se cierra y elimina para no volver a enviarle eventos.
		if err := s.sendLocked(client, event); err != nil {
			_ = client.conn.Close()
			delete(s.clients, client)
		}
	}
}

// send envía un evento a un cliente protegiendo la escritura con su mutex.
func (s *Server) send(client *client, event Event) {
	client.mu.Lock()
	defer client.mu.Unlock()
	// El error se ignora porque el cliente recibirá una limpieza al desconectarse.
	_ = writeEvent(client.conn, event)
}

// sendLocked es equivalente a send, pero se utiliza cuando s.mu ya está tomado.
func (s *Server) sendLocked(client *client, event Event) error {
	client.mu.Lock()
	defer client.mu.Unlock()
	return writeEvent(client.conn, event)
}

// writeEvent serializa un evento y lo escribe como una línea JSON.
func writeEvent(writer io.Writer, event Event) error {
	encoder := json.NewEncoder(writer)
	return encoder.Encode(event)
}

// ErrInvalidMessage es un error reutilizable para representar mensajes inválidos.
// Actualmente se conserva como parte de la API del paquete, aunque el flujo de
// lectura responde directamente con eventos de tipo error.
var ErrInvalidMessage = errors.New("invalid message")
