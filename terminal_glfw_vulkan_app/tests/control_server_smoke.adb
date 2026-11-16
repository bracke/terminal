with Ada.Streams;
with Ada.Strings;
with Ada.Strings.Fixed;
with AUnit.Assertions;
with GNAT.OS_Lib;
with GNAT.Sockets;
with Terminal.App.Control_Client;
with Terminal.App.Control_Server;

procedure Control_Server_Smoke is
   use AUnit.Assertions;
   use type Ada.Streams.Stream_Element_Offset;
   use type GNAT.Sockets.Socket_Type;
   package Server renames Terminal.App.Control_Server;
   use type Server.Poll_Status;
   use type Server.Reply_Status;
   use type Server.Start_Status;
   use type Terminal.App.Control_Client.Client_Status;
   Item : Server.Server;
   Start : Server.Start_Status;
   Poll : Server.Poll_Status;
   Reply : Server.Reply_Status;
   Client : GNAT.Sockets.Socket_Type := GNAT.Sockets.No_Socket;
   Request : constant String := "ping" & ASCII.LF;
   Bytes : Ada.Streams.Stream_Element_Array (1 .. Request'Length);
   Last : Ada.Streams.Stream_Element_Offset;
   Buffer : String (1 .. Server.Max_Request_Length);
   Length : Natural;
   Response : Ada.Streams.Stream_Element_Array (1 .. 16);
   Socket_Path : constant String :=
     "/tmp/bracke-control-smoke-"
       & Ada.Strings.Fixed.Trim
           (Integer'Image
              (GNAT.OS_Lib.Pid_To_Integer (GNAT.OS_Lib.Current_Process_Id)),
            Ada.Strings.Both)
       & ".sock";

   protected Client_Result is
      procedure Store
        (Text : String;
         Status : Terminal.App.Control_Client.Client_Status);
      entry Read
        (Text : out String;
         Length : out Natural;
         Status : out Terminal.App.Control_Client.Client_Status);
   private
      Value : String (1 .. 32) := (others => ' ');
      Value_Length : Natural := 0;
      Client_Status : Terminal.App.Control_Client.Client_Status :=
        Terminal.App.Control_Client.Receive_Failed;
      Ready : Boolean := False;
   end Client_Result;

   protected body Client_Result is
      procedure Store
        (Text : String;
         Status : Terminal.App.Control_Client.Client_Status) is
      begin
         Value_Length := Text'Length;
         if Text'Length > 0 then
            Value (1 .. Text'Length) := Text;
         end if;
         Client_Status := Status;
         Ready := True;
      end Store;

      entry Read
        (Text : out String;
         Length : out Natural;
         Status : out Terminal.App.Control_Client.Client_Status)
        when Ready
      is
      begin
         Length := Value_Length;
         if Length > 0 then
            Text (Text'First .. Text'First + Length - 1) := Value (1 .. Length);
         end if;
         Status := Client_Status;
      end Read;
   end Client_Result;

   task type Client_Task;
   task body Client_Task is
      Text : String (1 .. 32);
      Text_Length : Natural;
      Status : Terminal.App.Control_Client.Client_Status;
   begin
      Terminal.App.Control_Client.Execute
        (Socket_Path, "list", Text, Text_Length, Status);
      Client_Result.Store (Text (1 .. Text_Length), Status);
   end Client_Task;
begin
   Server.Start (Item, Socket_Path, Start);
   if Start /= Server.Started then
      raise Program_Error with "control server start: " & Start'Image;
   end if;
   Assert (Server.Active (Item), "control server active");
   Assert (Server.Path (Item) = Socket_Path, "control socket path retained");

   GNAT.Sockets.Create_Socket
     (Client, GNAT.Sockets.Family_Unix, GNAT.Sockets.Socket_Stream);
   GNAT.Sockets.Connect_Socket
     (Client, GNAT.Sockets.Unix_Socket_Address (Socket_Path));
   for I in Request'Range loop
      Bytes (Ada.Streams.Stream_Element_Offset (I - Request'First + 1)) :=
        Ada.Streams.Stream_Element (Character'Pos (Request (I)));
   end loop;
   GNAT.Sockets.Send_Socket (Client, Bytes, Last);
   Assert (Last = Bytes'Last, "control request sent");

   for Attempt in 1 .. 100 loop
      Server.Poll (Item, Buffer, Length, Poll);
      exit when Poll /= Server.No_Request;
      delay 0.001;
   end loop;
   if Poll /= Server.Request_Ready then
      raise Program_Error with "control server poll: " & Poll'Image;
   end if;
   Assert (Buffer (1 .. Length) = "ping", "control request text");

   Server.Reply (Item, "ok pong", Reply);
   if Reply /= Server.Reply_Sent then
      raise Program_Error with "control server reply: " & Reply'Image;
   end if;
   GNAT.Sockets.Receive_Socket (Client, Response, Last);
   Assert (Last = 8, "control reply length");
   declare
      Text : String (1 .. Natural (Last));
   begin
      for I in 1 .. Natural (Last) loop
         Text (I) := Character'Val (Response (Ada.Streams.Stream_Element_Offset (I)));
      end loop;
      Assert (Text = "ok pong" & ASCII.LF, "control reply text");
   end;
   GNAT.Sockets.Close_Socket (Client);
   Client := GNAT.Sockets.No_Socket;
   Server.Stop (Item);
   Assert (not Server.Active (Item), "control server stopped");

   Server.Start (Item, Socket_Path, Start);
   Assert (Start = Server.Started, "control server restarted for client");
   declare
      Runner : Client_Task;
      pragma Unreferenced (Runner);
      Client_Text : String (1 .. 32);
      Client_Length : Natural;
      Client_Status : Terminal.App.Control_Client.Client_Status;
   begin
      for Attempt in 1 .. 100 loop
         Server.Poll (Item, Buffer, Length, Poll);
         exit when Poll /= Server.No_Request;
         delay 0.001;
      end loop;
      Assert (Poll = Server.Request_Ready, "client request reached server");
      Assert (Buffer (1 .. Length) = "list", "client preserved request");
      Server.Reply (Item, "ok count=1", Reply);
      Assert (Reply = Server.Reply_Sent, "server replied to client");
      Client_Result.Read (Client_Text, Client_Length, Client_Status);
      Assert (Client_Status = Terminal.App.Control_Client.Ok, "client status");
      Assert
        (Client_Text (1 .. Client_Length) = "ok count=1",
         "client received response");
   end;
   Server.Stop (Item);
exception
   when others =>
      if Client /= GNAT.Sockets.No_Socket then
         GNAT.Sockets.Close_Socket (Client);
      end if;
      Server.Stop (Item);
      raise;
end Control_Server_Smoke;
