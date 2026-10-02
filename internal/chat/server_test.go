package chat

import (
	"bufio"
	"encoding/json"
	"net"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// 1. Prueba de integración: Registro, Historial y Broadcast
func TestServeConnReplaysHistoryAndBroadcasts(t *testing.T) {
	server, err := New(filepath.Join(t.TempDir(), "history.jsonl"))
	if err != nil {
		t.Fatal(err)
	}
	defer server.Close()

	firstServer, firstClient := testConnection(t)
	go server.ServeConn(firstServer)
	firstReader := bufio.NewReader(firstClient)

	// 1.1 Primer cliente (ana) envía solicitud de ingreso (join)
	sendRequest(t, firstClient, Request{Type: "join", User: "ana"})
	joinEvent := readEvent(t, firstReader, firstClient)
	if joinEvent.User != "Sistema" {
		t.Fatalf("se esperaba evento de ingreso del Sistema, se obtuvo: %#v", joinEvent)
	}

	// 1.2 Ana envía mensaje "hola"
	sendRequest(t, firstClient, Request{Type: "message", User: "ana", Text: "hola"})
	event := readEvent(t, firstReader, firstClient)
	if event.Text != "hola" {
		t.Fatalf("se esperaba mensaje 'hola', se obtuvo: %#v", event)
	}

	// 1.3 Segundo cliente (luis) se conecta y envía join
	secondServer, secondClient := testConnection(t)
	go server.ServeConn(secondServer)
	secondReader := bufio.NewReader(secondClient)

	sendRequest(t, secondClient, Request{Type: "join", User: "luis"})

	// Leer historial retransmitido a luis (Join de Ana + Mensaje 'hola' + Join de Luis)
	_ = readEvent(t, secondReader, secondClient)        // Join previo de Ana
	replayed := readEvent(t, secondReader, secondClient) // Mensaje "hola"
	if replayed.ID != event.ID {
		t.Fatalf("se esperaba ID retransmitido %d, se obtuvo %d", event.ID, replayed.ID)
	}
	_ = readEvent(t, secondReader, secondClient)        // Join propio de Luis

	// 1.4 Ana envía "adios" y Luis debe recibir el broadcast
	sendRequest(t, firstClient, Request{Type: "message", User: "ana", Text: "adios"})
	if received := readEvent(t, secondReader, secondClient); received.Text != "adios" {
		t.Fatalf("se esperaba broadcast 'adios', se obtuvo %#v", received)
	}

	_ = firstClient.Close()
	_ = secondClient.Close()
}

// 2. Prueba unitaria pura: Carga de archivo de historial
func TestLoadHistoryUnit(t *testing.T) {
	tmpDir := t.TempDir()
	historyFile := filepath.Join(tmpDir, "test_load.jsonl")

	server, err := New(historyFile)
	if err != nil {
		t.Fatalf("error creando servidor con archivo nuevo: %v", err)
	}
	if len(server.history) != 0 {
		t.Fatalf("se esperaba historial vacío, se obtuvo: %d registros", len(server.history))
	}
	server.Close()

	validJSON := `{"type":"message","id":1,"user":"ana","text":"hola","time":"2026-01-01T10:00:00Z"}` + "\n"
	if err := os.WriteFile(historyFile, []byte(validJSON), 0600); err != nil {
		t.Fatal(err)
	}

	server2, err := New(historyFile)
	if err != nil {
		t.Fatalf("error reabriendo servidor: %v", err)
	}
	defer server2.Close()

	if len(server2.history) != 1 {
		t.Fatalf("se esperaba 1 mensaje en el historial, se obtuvieron: %d", len(server2.history))
	}
	if server2.history[0].Text != "hola" {
		t.Fatalf("texto esperado 'hola', se obtuvo: %s", server2.history[0].Text)
	}
}

// 3. Prueba de errores de protocolo (mensajes vacíos o tipos inválidos)
func TestProtocolErrors(t *testing.T) {
	server, err := New(filepath.Join(t.TempDir(), "errors_history.jsonl"))
	if err != nil {
		t.Fatal(err)
	}
	defer server.Close()

	serverConn, clientConn := testConnection(t)
	go server.ServeConn(serverConn)
	defer clientConn.Close()

	reader := bufio.NewReader(clientConn)

	// Solicitud con tipo inválido
	sendRequest(t, clientConn, Request{Type: "invalid_type", User: "test"})
	errEvent := readEvent(t, reader, clientConn)
	if errEvent.Type != "error" {
		t.Fatalf("se esperaba tipo 'error', se obtuvo: %s", errEvent.Type)
	}

	// Mensaje de texto vacío
	sendRequest(t, clientConn, Request{Type: "message", User: "test", Text: ""})
	errEvent = readEvent(t, reader, clientConn)
	if errEvent.Type != "error" {
		t.Fatalf("se esperaba 'error' ante mensaje vacío, se obtuvo: %s", errEvent.Type)
	}
}

// 4. Prueba de continuidad de IDs tras reiniciar el servidor
func TestServerRestartContinuity(t *testing.T) {
	historyPath := filepath.Join(t.TempDir(), "restart_history.jsonl")

	// Sesión 1: Iniciar servidor, registrar a pedro y publicar mensaje
	server1, err := New(historyPath)
	if err != nil {
		t.Fatal(err)
	}
	sConn1, cConn1 := testConnection(t)
	go server1.ServeConn(sConn1)
	r1 := bufio.NewReader(cConn1)

	sendRequest(t, cConn1, Request{Type: "join", User: "pedro"})
	_ = readEvent(t, r1, cConn1) // Evento join

	sendRequest(t, cConn1, Request{Type: "message", User: "pedro", Text: "primer msj"})
	e1 := readEvent(t, r1, cConn1) // Mensaje enviado

	cConn1.Close()
	server1.Close()

	// Sesión 2: Reabrir el servidor con el mismo archivo
	server2, err := New(historyPath)
	if err != nil {
		t.Fatal(err)
	}
	defer server2.Close()

	sConn2, cConn2 := testConnection(t)
	go server2.ServeConn(sConn2)
	defer cConn2.Close()
	r2 := bufio.NewReader(cConn2)

	// Enviar join para solicitar el historial previo
	sendRequest(t, cConn2, Request{Type: "join", User: "pedro"})

	_ = readEvent(t, r2, cConn2)                // Historial: Join anterior
	replayedMessage := readEvent(t, r2, cConn2) // Historial: Mensaje "primer msj"

	if replayedMessage.ID != e1.ID {
		t.Fatalf("se esperaba ID continuo %d, se obtuvo: %d", e1.ID, replayedMessage.ID)
	}
}

// 5. Prueba de anuncio de desconexión de usuario
func TestUserDisconnectNotification(t *testing.T) {
	server, err := New(filepath.Join(t.TempDir(), "disconnect_history.jsonl"))
	if err != nil {
		t.Fatal(err)
	}
	defer server.Close()

	sConn1, cConn1 := testConnection(t)
	go server.ServeConn(sConn1)
	r1 := bufio.NewReader(cConn1)

	// Registramos al usuario Ana
	sendRequest(t, cConn1, Request{Type: "join", User: "Ana"})
	_ = readEvent(t, r1, cConn1)

	// Conectamos a Carlos
	sConn2, cConn2 := testConnection(t)
	go server.ServeConn(sConn2)
	sendRequest(t, cConn2, Request{Type: "join", User: "Carlos"})

	// Ana recibe notificación de que Carlos entró
	_ = readEvent(t, r1, cConn1)

	// Carlos se desconecta
	cConn2.Close()

	// Ana debe recibir la notificación de desconexión del Sistema
	disconnectEvent := readEvent(t, r1, cConn1)
	if disconnectEvent.User != "Sistema" || !strings.Contains(disconnectEvent.Text, "se ha desconectado") {
		t.Fatalf("se esperaba anuncio de salida del Sistema, se obtuvo: %#v", disconnectEvent)
	}
}

// Auxiliares de red
func testConnection(t *testing.T) (net.Conn, net.Conn) {
	t.Helper()
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	serverConn := make(chan net.Conn, 1)
	go func() {
		conn, acceptErr := listener.Accept()
		if acceptErr == nil {
			serverConn <- conn
		}
	}()
	clientConn, err := net.Dial("tcp", listener.Addr().String())
	if err != nil {
		_ = listener.Close()
		t.Fatal(err)
	}
	_ = listener.Close()
	return <-serverConn, clientConn
}

func sendRequest(t *testing.T, conn net.Conn, request Request) {
	t.Helper()
	_ = conn.SetWriteDeadline(time.Now().Add(2 * time.Second))
	if err := json.NewEncoder(conn).Encode(request); err != nil {
		t.Fatal(err)
	}
}

func readEvent(t *testing.T, reader *bufio.Reader, conn net.Conn) Event {
	t.Helper()
	_ = conn.SetReadDeadline(time.Now().Add(2 * time.Second))
	var event Event
	if err := json.NewDecoder(reader).Decode(&event); err != nil {
		t.Fatalf("error o tiempo agotado leyendo del socket: %v", err)
	}
	return event
}