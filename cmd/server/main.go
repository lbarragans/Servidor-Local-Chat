package main

import (
	"flag"
	"log"
	"net"
	"os"
	"os/signal"
	"syscall"

	"github.com/lbarragans/Servidor-Local-Chat/internal/chat"
)

func main() {
	address := flag.String("addr", ":9000", "TCP address to listen on")
	historyPath := flag.String("history", "chat-history.jsonl", "path to the chat history file")
	flag.Parse()

	server, err := chat.New(*historyPath)
	if err != nil {
		log.Fatalf("start chat server: %v", err)
	}
	defer server.Close()

	listener, err := net.Listen("tcp", *address)
	if err != nil {
		log.Fatalf("listen on %s: %v", *address, err)
	}
	defer listener.Close()

	log.Printf("chat server listening on %s", listener.Addr())
	shutdown := make(chan os.Signal, 1)
	signal.Notify(shutdown, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-shutdown
		_ = listener.Close()
	}()

	for {
		conn, err := listener.Accept()
		if err != nil {
			select {
			case <-shutdown:
				return
			default:
				log.Printf("accept connection: %v", err)
				continue
			}
		}
		go server.ServeConn(conn)
	}
}
