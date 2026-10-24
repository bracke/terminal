with Terminal.App.PTY_Reader;
with Terminal.App.PTY_Write;
with Terminal.App.Queues;
with Terminal.Core;
with Terminal.PTY.Backend;

package Terminal.App.Session_Runtime is
   Max_Status_Label_Length : constant := 96;

   type Start_Status is
     (Ok,
      Core_Init_Failed,
      Spawn_Failed,
      Allocation_Failed);

   type Runtime_Status is
     (Inactive,
      Active,
      Closed);

   type Runtime is limited private;

   procedure Start
     (R                : in out Runtime;
      Rows             : Positive;
      Cols             : Positive;
      Scrollback_Limit : Natural;
      Status           : out Start_Status;
      Graphics_Profile : Terminal.Core.Graphics_Capability_Profile :=
        Terminal.App.Core_Graphics_Profile);

   procedure Poll_Output
     (R      : in out Runtime;
      Status : out Terminal.Core.Feed_Status);

   procedure Write
     (R      : in out Runtime;
      Chunk  : Terminal.App.Queues.Byte_Chunk;
      Status : out Terminal.App.PTY_Write.Write_All_Status);

   procedure Resize
     (R          : in out Runtime;
      Rows       : Positive;
      Cols       : Positive;
      Core_Status : out Terminal.Core.Resize_Status;
      PTY_Status  : out Terminal.PTY.Backend.Resize_Status);

   procedure Close (R : in out Runtime);

   function State (R : Runtime) return Runtime_Status;
   function Graphics_Stream_ID
     (R : Runtime) return Terminal.Core.Graphics_Stream_ID;
   function Core (R : Runtime) return access Terminal.Core.Terminal;
   function PTY_Queue
     (R : Runtime) return access Terminal.App.Queues.PTY_Output_Queue;
   function Is_Alive (R : Runtime) return Boolean;
   function Status_Label (R : Runtime) return String;

private
   type Core_Access is access all Terminal.Core.Terminal;
   type Session_Access is access all Terminal.PTY.Backend.Session;
   type PTY_Queue_Access is access all Terminal.App.Queues.PTY_Output_Queue;
   type Reader_Access is access Terminal.App.PTY_Reader.Reader;

   type Runtime is limited record
      Current_State : Runtime_Status := Inactive;
      T             : Core_Access := null;
      S             : Session_Access := null;
      Q             : PTY_Queue_Access := null;
      Reader        : Reader_Access := null;
      Stream_ID     : Terminal.Core.Graphics_Stream_ID := 0;
      Rows          : Positive := 1;
      Cols          : Positive := 1;
      Size_Known    : Boolean := False;
      Last_Start    : Start_Status := Allocation_Failed;
      Last_Spawn    : Terminal.PTY.Backend.Spawn_Status :=
        Terminal.PTY.Backend.Fork_Failed;
   end record;
end Terminal.App.Session_Runtime;
