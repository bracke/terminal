with Ada.Environment_Variables;
with Ada.Real_Time;
with Ada.Streams;
with Ada.Strings;
with Ada.Strings.Fixed;
with GNAT.OS_Lib;
with GNAT.Sockets;
with Terminal.App.Platform_Control;

package body Terminal.App.Control_Server is
   use type Ada.Real_Time.Time;
   use type Ada.Streams.Stream_Element_Offset;
   use type GNAT.Sockets.Selector_Status;
   use type GNAT.Sockets.Socket_Type;

   Client_Timeout : constant Duration := 2.0;

   function Trimmed (Value : Integer) return String is
     (Ada.Strings.Fixed.Trim (Integer'Image (Value), Ada.Strings.Both));

   function Default_Path return String is
      Runtime : constant String :=
        (if Ada.Environment_Variables.Exists ("XDG_RUNTIME_DIR")
         then Ada.Environment_Variables.Value ("XDG_RUNTIME_DIR")
         else "/tmp");
      PID : constant Integer := GNAT.OS_Lib.Pid_To_Integer
        (GNAT.OS_Lib.Current_Process_Id);
   begin
      return Runtime & "/bracke-terminal-" & Trimmed (PID) & ".sock";
   end Default_Path;

   procedure Close_Client (Item : in out Server) is
   begin
      if Item.Client /= GNAT.Sockets.No_Socket then
         GNAT.Sockets.Close_Socket (Item.Client);
         Item.Client := GNAT.Sockets.No_Socket;
      end if;
      Item.Request_Length := 0;
   exception
      when GNAT.Sockets.Socket_Error =>
         Item.Client := GNAT.Sockets.No_Socket;
         Item.Request_Length := 0;
   end Close_Client;

   procedure Stop (Item : in out Server) is
   begin
      Close_Client (Item);
      if Item.Listener /= GNAT.Sockets.No_Socket then
         GNAT.Sockets.Close_Socket (Item.Listener);
         Item.Listener := GNAT.Sockets.No_Socket;
      end if;
      if Item.Socket_Path_Length > 0 then
         declare
            Name : constant String :=
              Item.Socket_Path (1 .. Item.Socket_Path_Length);
         begin
            Terminal.App.Platform_Control.Remove_Socket (Name);
         end;
      end if;
      Item.Socket_Path_Length := 0;
      Item.Is_Active := False;
   exception
      when GNAT.Sockets.Socket_Error =>
         Item.Listener := GNAT.Sockets.No_Socket;
         Item.Socket_Path_Length := 0;
         Item.Is_Active := False;
   end Stop;

   overriding procedure Finalize (Item : in out Server) is
   begin
      Stop (Item);
   end Finalize;

   procedure Start
     (Item   : in out Server;
      Path   : String;
      Status : out Start_Status)
   is
      Request : GNAT.Sockets.Request_Type (GNAT.Sockets.Non_Blocking_IO);
   begin
      if Item.Is_Active then
         Status := Already_Started;
         return;
      elsif Path'Length = 0 or else Path'Length > Max_Socket_Path_Length then
         Status := Invalid_Path;
         return;
      end if;

      GNAT.Sockets.Initialize;
      GNAT.Sockets.Create_Socket
        (Item.Listener, GNAT.Sockets.Family_Unix, GNAT.Sockets.Socket_Stream);
      GNAT.Sockets.Bind_Socket
        (Item.Listener, GNAT.Sockets.Unix_Socket_Address (Path));
      Item.Socket_Path (1 .. Path'Length) := Path;
      Item.Socket_Path_Length := Path'Length;
      if not Terminal.App.Platform_Control.Restrict_To_Owner (Path) then
         Stop (Item);
         Status := Permission_Failed;
         return;
      end if;
      GNAT.Sockets.Listen_Socket (Item.Listener, 4);
      Request.Enabled := True;
      GNAT.Sockets.Control_Socket (Item.Listener, Request);
      Item.Is_Active := True;
      Status := Started;
   exception
      when GNAT.Sockets.Socket_Error =>
         Stop (Item);
         Status := Socket_Failed;
   end Start;

   procedure Poll
     (Item   : in out Server;
      Text   : out String;
      Length : out Natural;
      Status : out Poll_Status)
   is
      Address : GNAT.Sockets.Sock_Addr_Type;
      Select_Status : GNAT.Sockets.Selector_Status;
      Available : GNAT.Sockets.Request_Type (GNAT.Sockets.N_Bytes_To_Read);
      Buffer : Ada.Streams.Stream_Element_Array (1 .. 1_024);
      Last : Ada.Streams.Stream_Element_Offset;
   begin
      Length := 0;
      Status := No_Request;
      if not Item.Is_Active then
         return;
      end if;

      if Item.Client = GNAT.Sockets.No_Socket then
         GNAT.Sockets.Accept_Socket
           (Item.Listener, Item.Client, Address, 0.0, Status => Select_Status);
         if Select_Status /= GNAT.Sockets.Completed then
            Item.Client := GNAT.Sockets.No_Socket;
            return;
         end if;
         Item.Accepted_At := Ada.Real_Time.Clock;
         declare
            Nonblocking : GNAT.Sockets.Request_Type
              (GNAT.Sockets.Non_Blocking_IO);
         begin
            Nonblocking.Enabled := True;
            GNAT.Sockets.Control_Socket (Item.Client, Nonblocking);
         end;
      elsif Ada.Real_Time.To_Duration
        (Ada.Real_Time.Clock - Item.Accepted_At) > Client_Timeout
      then
         Close_Client (Item);
         Status := Client_Failed;
         return;
      end if;

      GNAT.Sockets.Control_Socket (Item.Client, Available);
      if Available.Size = 0 then
         return;
      end if;
      GNAT.Sockets.Receive_Socket (Item.Client, Buffer, Last);
      if Last < Buffer'First then
         Close_Client (Item);
         Status := Client_Failed;
         return;
      end if;

      for I in Buffer'First .. Last loop
         declare
            Ch : constant Character := Character'Val (Buffer (I));
         begin
            if Ch = ASCII.LF then
               Length := Item.Request_Length;
               if Length > Text'Length then
                  Close_Client (Item);
                  Status := Request_Too_Long;
                  return;
               end if;
               if Length > 0 and then Item.Request (Length) = ASCII.CR then
                  Length := Length - 1;
               end if;
               if Length > 0 then
                  Text (Text'First .. Text'First + Length - 1) :=
                    Item.Request (1 .. Length);
               end if;
               Status := Request_Ready;
               return;
            elsif Item.Request_Length = Max_Request_Length then
               Status := Request_Too_Long;
               return;
            else
               Item.Request_Length := Item.Request_Length + 1;
               Item.Request (Item.Request_Length) := Ch;
            end if;
         end;
      end loop;
   exception
      when GNAT.Sockets.Socket_Error | Constraint_Error =>
         Close_Client (Item);
         Length := 0;
         Status := Client_Failed;
   end Poll;

   procedure Reply
     (Item   : in out Server;
      Text   : String;
      Status : out Reply_Status)
   is
      Data : Ada.Streams.Stream_Element_Array (1 .. Text'Length + 1);
      Last : Ada.Streams.Stream_Element_Offset;
      Blocking : GNAT.Sockets.Request_Type (GNAT.Sockets.Non_Blocking_IO);
   begin
      if Item.Client = GNAT.Sockets.No_Socket then
         Status := No_Client;
         return;
      elsif Text'Length > Max_Response_Length then
         Close_Client (Item);
         Status := Reply_Too_Long;
         return;
      end if;
      for I in Text'Range loop
         Data (Ada.Streams.Stream_Element_Offset (I - Text'First + 1)) :=
           Ada.Streams.Stream_Element (Character'Pos (Text (I)));
      end loop;
      Data (Data'Last) := Ada.Streams.Stream_Element (Character'Pos (ASCII.LF));
      Blocking.Enabled := False;
      GNAT.Sockets.Control_Socket (Item.Client, Blocking);
      GNAT.Sockets.Send_Socket (Item.Client, Data, Last);
      Status :=
        (if Last = Data'Last then Reply_Sent else Reply_Failed);
      Close_Client (Item);
   exception
      when GNAT.Sockets.Socket_Error | Constraint_Error =>
         Close_Client (Item);
         Status := Reply_Failed;
   end Reply;

   function Active (Item : Server) return Boolean is (Item.Is_Active);

   function Path (Item : Server) return String is
     (if Item.Socket_Path_Length = 0 then ""
      else Item.Socket_Path (1 .. Item.Socket_Path_Length));
end Terminal.App.Control_Server;
