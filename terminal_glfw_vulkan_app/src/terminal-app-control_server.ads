with Ada.Finalization;
private with Ada.Real_Time;
private with GNAT.Sockets;

package Terminal.App.Control_Server is
   Max_Socket_Path_Length : constant := 100;
   Max_Request_Length : constant := 4_096;
   Max_Response_Length : constant := 65_536;

   type Start_Status is
     (Started,
      Already_Started,
      Invalid_Path,
      Address_In_Use,
      Permission_Failed,
      Socket_Failed);

   type Poll_Status is
     (No_Request,
      Request_Ready,
      Request_Too_Long,
      Client_Failed);

   type Reply_Status is (Reply_Sent, No_Client, Reply_Too_Long, Reply_Failed);

   type Server is new Ada.Finalization.Limited_Controlled with private;

   function Default_Path return String;
   procedure Start
     (Item   : in out Server;
      Path   : String;
      Status : out Start_Status);
   procedure Poll
     (Item   : in out Server;
      Text   : out String;
      Length : out Natural;
      Status : out Poll_Status);
   procedure Reply
     (Item   : in out Server;
      Text   : String;
      Status : out Reply_Status);
   procedure Stop (Item : in out Server);
   function Active (Item : Server) return Boolean;
   function Path (Item : Server) return String;

private
   subtype Socket_Path_Index is Positive range 1 .. Max_Socket_Path_Length;
   subtype Request_Index is Positive range 1 .. Max_Request_Length;

   type Server is new Ada.Finalization.Limited_Controlled with record
      Listener : GNAT.Sockets.Socket_Type := GNAT.Sockets.No_Socket;
      Client   : GNAT.Sockets.Socket_Type := GNAT.Sockets.No_Socket;
      Socket_Path : String (Socket_Path_Index) := (others => ' ');
      Socket_Path_Length : Natural range 0 .. Max_Socket_Path_Length := 0;
      Request : String (Request_Index) := (others => ' ');
      Request_Length : Natural range 0 .. Max_Request_Length := 0;
      Accepted_At : Ada.Real_Time.Time := Ada.Real_Time.Time_First;
      Is_Active : Boolean := False;
   end record;

   overriding procedure Finalize (Item : in out Server);
end Terminal.App.Control_Server;
