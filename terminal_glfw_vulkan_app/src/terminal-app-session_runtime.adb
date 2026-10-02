with Ada.Unchecked_Deallocation;
package body Terminal.App.Session_Runtime is
   use type Terminal.App.PTY_Write.Write_All_Status;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Initialize_Status;
   use type Terminal.Core.Resize_Status;
   use type Terminal.PTY.Backend.Resize_Status;
   use type Terminal.PTY.Backend.Spawn_Status;

   procedure Free_Core is new Ada.Unchecked_Deallocation
     (Terminal.Core.Terminal,
      Core_Access);
   procedure Free_Session is new Ada.Unchecked_Deallocation
     (Terminal.PTY.Backend.Session,
      Session_Access);
   procedure Free_Queue is new Ada.Unchecked_Deallocation
     (Terminal.App.Queues.PTY_Output_Queue,
      PTY_Queue_Access);
   procedure Free_Reader is new Ada.Unchecked_Deallocation
     (Terminal.App.PTY_Reader.Reader,
      Reader_Access);

   function Trim_Image (Value : Natural) return String is
      Text : constant String := Natural'Image (Value);
   begin
      return Text (Text'First + 1 .. Text'Last);
   end Trim_Image;

   procedure Stop_Reader (R : in out Runtime) is
   begin
      if R.Reader /= null then
         begin
            R.Reader.Stop;
         exception
            when Tasking_Error =>
               null;
         end;
         Free_Reader (R.Reader);
      end if;
   end Stop_Reader;

   procedure Close (R : in out Runtime) is
   begin
      if R.S /= null then
         Terminal.PTY.Backend.Close (R.S.all);
      end if;
      Stop_Reader (R);
      if R.S /= null then
         Free_Session (R.S);
      end if;
      if R.Q /= null then
         Free_Queue (R.Q);
      end if;
      if R.T /= null then
         Free_Core (R.T);
      end if;
      R.Current_State := Closed;
   end Close;

   procedure Start
     (R                : in out Runtime;
      Rows             : Positive;
      Cols             : Positive;
      Scrollback_Limit : Natural;
      Status           : out Start_Status)
   is
      Core_Status : Terminal.Core.Initialize_Status;
      Spawn_Status : Terminal.PTY.Backend.Spawn_Status;
   begin
      if R.Current_State = Active then
         Close (R);
      end if;

      R.T := new Terminal.Core.Terminal;
      R.S := new Terminal.PTY.Backend.Session;
      R.Q := new Terminal.App.Queues.PTY_Output_Queue;

      Terminal.Core.Initialize
        (R.T.all, Rows, Cols, Scrollback_Limit, Core_Status);
      if Core_Status /= Terminal.Core.Ok then
         Status := Core_Init_Failed;
         R.Last_Start := Status;
         Close (R);
         return;
      end if;

      Terminal.PTY.Backend.Spawn_Default_Shell
        (R.S.all, Rows, Cols, Spawn_Status);
      R.Last_Spawn := Spawn_Status;
      if Spawn_Status /= Terminal.PTY.Backend.Ok then
         Status := Spawn_Failed;
         R.Last_Start := Status;
         Close (R);
         return;
      end if;

      R.Reader :=
        new Terminal.App.PTY_Reader.Reader
          (R.S.all'Unchecked_Access, R.Q.all'Unchecked_Access);
      R.Current_State := Active;
      Status := Ok;
      R.Last_Start := Status;
   exception
      when Storage_Error =>
         Status := Allocation_Failed;
         R.Last_Start := Status;
         Close (R);
   end Start;

   procedure Poll_Output
     (R      : in out Runtime;
      Status : out Terminal.Core.Feed_Status)
   is
      Chunk : Terminal.App.Queues.Byte_Chunk;
      Has_Chunk : Boolean;
      Feed : Terminal.Core.Feed_Status := Terminal.Core.Ok;
   begin
      Status := Terminal.Core.Ok;
      if R.Current_State /= Active or else R.T = null or else R.Q = null then
         Status := Terminal.Core.Invalid_State;
         return;
      end if;

      loop
         R.Q.Pop (Chunk, Has_Chunk);
         exit when not Has_Chunk;
         if Chunk.Length > 0 then
            Terminal.Core.Feed (R.T.all, Chunk.Data (1 .. Chunk.Length), Feed);
            Status := Feed;
         end if;
      end loop;
   end Poll_Output;

   procedure Write
     (R      : in out Runtime;
      Chunk  : Terminal.App.Queues.Byte_Chunk;
      Status : out Terminal.App.PTY_Write.Write_All_Status)
   is
   begin
      if R.Current_State /= Active or else R.S = null then
         Status := Terminal.App.PTY_Write.Session_Closed;
      else
         Terminal.App.PTY_Write.Write_All (R.S.all, Chunk, Status);
      end if;
   end Write;

   procedure Resize
     (R          : in out Runtime;
      Rows       : Positive;
      Cols       : Positive;
      Core_Status : out Terminal.Core.Resize_Status;
      PTY_Status  : out Terminal.PTY.Backend.Resize_Status)
   is
   begin
      if R.Current_State /= Active or else R.T = null or else R.S = null then
         Core_Status := Terminal.Core.Invalid_Size;
         PTY_Status := Terminal.PTY.Backend.Session_Closed;
      else
         Terminal.Core.Resize (R.T.all, Rows, Cols, Core_Status);
         Terminal.PTY.Backend.Resize (R.S.all, Rows, Cols, PTY_Status);
      end if;
   end Resize;

   function State (R : Runtime) return Runtime_Status is
     (R.Current_State);

   function Core (R : Runtime) return access Terminal.Core.Terminal is
   begin
      return R.T;
   end Core;

   function PTY_Queue
     (R : Runtime) return access Terminal.App.Queues.PTY_Output_Queue is
   begin
      return R.Q;
   end PTY_Queue;

   function Is_Alive (R : Runtime) return Boolean is
   begin
      return R.Current_State = Active
        and then R.S /= null
        and then Terminal.PTY.Backend.Is_Alive (R.S.all);
   end Is_Alive;

   function Status_Label (R : Runtime) return String is
   begin
      case R.Current_State is
         when Inactive =>
            return "Session runtime inactive";
         when Active =>
            return
              "Session runtime active; queued="
              & (if R.Q = null then "0" else Trim_Image (R.Q.Length));
         when Closed =>
            return "Session runtime closed";
      end case;
   end Status_Label;
end Terminal.App.Session_Runtime;
