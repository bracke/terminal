with Ada.Streams;
with GNAT.Sockets;
with Terminal.App.Control_Protocol;
with Terminal.App.Control_Server;

package body Terminal.App.Control_Client is
   use type Ada.Streams.Stream_Element_Offset;
   use type GNAT.Sockets.Socket_Type;

   procedure Execute
     (Path     : String;
      Request  : String;
      Response : out String;
      Length   : out Natural;
      Status   : out Client_Status)
   is
      Socket : GNAT.Sockets.Socket_Type := GNAT.Sockets.No_Socket;
      Data : Ada.Streams.Stream_Element_Array (1 .. Request'Length + 1);
      Last : Ada.Streams.Stream_Element_Offset;
      Buffer : Ada.Streams.Stream_Element_Array (1 .. 1_024);
      Done : Boolean := False;

      procedure Close is
      begin
         if Socket /= GNAT.Sockets.No_Socket then
            GNAT.Sockets.Close_Socket (Socket);
            Socket := GNAT.Sockets.No_Socket;
         end if;
      exception
         when GNAT.Sockets.Socket_Error =>
            Socket := GNAT.Sockets.No_Socket;
      end Close;
   begin
      Length := 0;
      if Path'Length = 0
        or else Path'Length > Terminal.App.Control_Server.Max_Socket_Path_Length
      then
         Status := Invalid_Path;
         return;
      elsif Request'Length > Terminal.App.Control_Protocol.Max_Request_Length then
         Status := Request_Too_Long;
         return;
      end if;

      GNAT.Sockets.Initialize;
      GNAT.Sockets.Create_Socket
        (Socket, GNAT.Sockets.Family_Unix, GNAT.Sockets.Socket_Stream);
      begin
         GNAT.Sockets.Connect_Socket
           (Socket, GNAT.Sockets.Unix_Socket_Address (Path));
      exception
         when GNAT.Sockets.Socket_Error =>
            Close;
            Status := Connect_Failed;
            return;
      end;

      for I in Request'Range loop
         Data (Ada.Streams.Stream_Element_Offset (I - Request'First + 1)) :=
           Ada.Streams.Stream_Element (Character'Pos (Request (I)));
      end loop;
      Data (Data'Last) := Ada.Streams.Stream_Element (Character'Pos (ASCII.LF));
      GNAT.Sockets.Send_Socket (Socket, Data, Last);
      if Last /= Data'Last then
         Close;
         Status := Send_Failed;
         return;
      end if;

      while not Done loop
         GNAT.Sockets.Receive_Socket (Socket, Buffer, Last);
         if Last < Buffer'First then
            exit;
         end if;
         for I in Buffer'First .. Last loop
            declare
               Ch : constant Character := Character'Val (Buffer (I));
            begin
               if Ch = ASCII.LF then
                  Done := True;
                  exit;
               elsif Length = Response'Length then
                  Close;
                  Status := Response_Too_Long;
                  return;
               else
                  Length := Length + 1;
                  Response (Response'First + Length - 1) := Ch;
               end if;
            end;
         end loop;
      end loop;
      if Length > 0
        and then Response (Response'First + Length - 1) = ASCII.CR
      then
         Length := Length - 1;
      end if;
      Close;
      Status := Ok;
   exception
      when GNAT.Sockets.Socket_Error | Constraint_Error =>
         Close;
         Length := 0;
         Status := Receive_Failed;
   end Execute;

   function Status_Label (Status : Client_Status) return String is
     (case Status is
         when Ok                => "ok",
         when Invalid_Path      => "invalid socket path",
         when Request_Too_Long  => "request too long",
         when Connect_Failed    => "connection failed",
         when Send_Failed       => "send failed",
         when Response_Too_Long => "response too long",
         when Receive_Failed    => "receive failed");
end Terminal.App.Control_Client;
