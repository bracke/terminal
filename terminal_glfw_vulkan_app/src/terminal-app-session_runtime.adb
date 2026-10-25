with Ada.Unchecked_Deallocation;
package body Terminal.App.Session_Runtime is
   use type Terminal.App.PTY_Write.Write_All_Status;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Initialize_Status;
   use type Terminal.Core.Resize_Status;
   use type Terminal.Core.Graphics_Stream_ID;
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

   Next_Graphics_Stream_ID : Terminal.Core.Graphics_Stream_ID := 1;

   function Allocate_Graphics_Stream_ID
     return Terminal.Core.Graphics_Stream_ID
   is
      Result : constant Terminal.Core.Graphics_Stream_ID :=
        Next_Graphics_Stream_ID;
   begin
      Next_Graphics_Stream_ID := Next_Graphics_Stream_ID + 1;
      if Next_Graphics_Stream_ID = 0 then
         Next_Graphics_Stream_ID := 1;
      end if;
      return Result;
   end Allocate_Graphics_Stream_ID;

   function Trim_Image (Value : Natural) return String is
      Text : constant String := Natural'Image (Value);
   begin
      return Text (Text'First + 1 .. Text'Last);
   end Trim_Image;

   function Feed_Rank (Status : Terminal.Core.Feed_Status) return Natural is
     (case Status is
         when Terminal.Core.Ok               => 0,
         when Terminal.Core.Parser_Recovered => 1,
         when Terminal.Core.Parser_Overflow  => 2,
         when Terminal.Core.Invalid_State    => 3);

   function Has_Resources (R : Runtime) return Boolean is
     (R.T /= null or else R.S /= null or else R.Q /= null
      or else R.Reader /= null);

   procedure Stop_Reader
     (R       : in out Runtime;
      Success : out Boolean)
   is
   begin
      Success := True;
      if R.Reader /= null then
         begin
            R.Reader.Stop;
         exception
            when Tasking_Error =>
               null;
            when others =>
               Success := False;
               return;
         end;
         begin
            Free_Reader (R.Reader);
         exception
            when others => Success := False;
         end;
      end if;
   end Stop_Reader;

   procedure Close (R : in out Runtime) is
      Queue_Closed    : Boolean := True;
      Session_Closed  : Boolean := True;
      Reader_Stopped  : Boolean := True;
      Core_Closed     : Boolean := True;
   begin
      if R.Q /= null then
         begin
            R.Q.Shut_Down;
         exception
            when others => Queue_Closed := False;
         end;
      end if;
      if R.S /= null then
         begin
            Terminal.PTY.Backend.Close (R.S.all);
         exception
            when others => Session_Closed := False;
         end;
      end if;
      Stop_Reader (R, Reader_Stopped);
      if R.S /= null and then Session_Closed then
         begin
            Free_Session (R.S);
         exception
            when others => Session_Closed := False;
         end;
      end if;
      if R.Q /= null and then Queue_Closed and then Reader_Stopped then
         begin
            Free_Queue (R.Q);
         exception
            when others => Queue_Closed := False;
         end;
      end if;
      if R.T /= null then
         begin
            Terminal.Core.Finalize (R.T.all);
         exception
            when others => Core_Closed := False;
         end;
         if Core_Closed then
            begin
               Free_Core (R.T);
            exception
               when others => Core_Closed := False;
            end;
         end if;
      end if;
      R.Size_Known := False;
      R.Pending_Write := (others => <>);
      R.Pending_Write_Offset := 1;
      R.Current_State :=
        (if Has_Resources (R) then Cleanup_Pending else Closed);
   end Close;

   overriding procedure Finalize (R : in out Runtime) is
   begin
      Close (R);
      if R.Current_State /= Closed then
         raise Program_Error with "session runtime finalization is incomplete";
      end if;
   end Finalize;

   procedure Start
     (R                : in out Runtime;
      Rows             : Positive;
      Cols             : Positive;
      Scrollback_Limit : Natural;
      Status           : out Start_Status;
      Graphics_Profile : Terminal.Core.Graphics_Capability_Profile :=
        Terminal.App.Core_Graphics_Profile)
   is
      Core_Status : Terminal.Core.Initialize_Status;
      Spawn_Status : Terminal.PTY.Backend.Spawn_Status;
   begin
      if Has_Resources (R) then
         Close (R);
      end if;

      if Has_Resources (R) then
         R.Current_State := Cleanup_Pending;
         Status := Cleanup_Failed;
         R.Last_Start := Status;
         return;
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

      Terminal.Core.Set_Graphics_Capabilities
        (R.T.all, Graphics_Profile);
      R.Stream_ID := Allocate_Graphics_Stream_ID;
      Terminal.Core.Set_Graphics_Stream_ID (R.T.all, R.Stream_ID);

      Terminal.PTY.Backend.Spawn_Default_Shell
        (R.S.all,
         Rows,
         Cols,
         Spawn_Status,
         Terminal.App.Graphics_Feature_Report (Graphics_Profile));
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
      R.Rows := Rows;
      R.Cols := Cols;
      R.Size_Known := True;
      R.Pending_Write := (others => <>);
      R.Pending_Write_Offset := 1;
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
      Write_Status : Terminal.App.PTY_Write.Write_All_Status;
      Had_Output   : Boolean;
   begin
      Poll_Output (R, Status, Write_Status, Had_Output);
   end Poll_Output;

   procedure Poll_Output
     (R            : in out Runtime;
      Status       : out Terminal.Core.Feed_Status;
      Write_Status : out Terminal.App.PTY_Write.Write_All_Status;
      Had_Output   : out Boolean)
   is
      Chunk : Terminal.App.Queues.Byte_Chunk;
      Has_Chunk : Boolean;
      Feed : Terminal.Core.Feed_Status := Terminal.Core.Ok;
   begin
      Status := Terminal.Core.Ok;
      Write_Status := Terminal.App.PTY_Write.Ok;
      Had_Output := False;
      if R.Current_State = Exited then
         return;
      elsif R.Current_State /= Active or else R.T = null or else R.Q = null then
         Status := Terminal.Core.Invalid_State;
         return;
      end if;

      Flush_Write (R, Write_Status);
      if Write_Status in
        Terminal.App.PTY_Write.Failed | Terminal.App.PTY_Write.Session_Closed
      then
         return;
      end if;

      loop
         R.Q.Pop (Chunk, Has_Chunk);
         exit when not Has_Chunk;
         if Chunk.Length > 0 then
            Had_Output := True;
            Terminal.Core.Feed (R.T.all, Chunk.Data (1 .. Chunk.Length), Feed);
            if Feed_Rank (Feed) > Feed_Rank (Status) then
               Status := Feed;
            end if;
         end if;
      end loop;

      while not Has_Pending_Write (R)
        and then Terminal.Core.Pending_Response_Length (R.T.all) > 0
      loop
         Chunk := (others => <>);
         Terminal.Core.Read_Response (R.T.all, Chunk.Data, Chunk.Length);
         exit when Chunk.Length = 0;
         Write (R, Chunk, Write_Status);
         exit when Write_Status /= Terminal.App.PTY_Write.Ok;
      end loop;

      if R.Reader /= null and then R.Reader.all'Terminated then
         R.Current_State := Exited;
      end if;
   end Poll_Output;

   procedure Write
     (R      : in out Runtime;
      Chunk  : Terminal.App.Queues.Byte_Chunk;
      Status : out Terminal.App.PTY_Write.Write_All_Status)
   is
   begin
      if R.Current_State /= Active or else R.S = null then
         Status := Terminal.App.PTY_Write.Session_Closed;
      elsif Has_Pending_Write (R) then
         Status := Terminal.App.PTY_Write.Incomplete;
      else
         R.Pending_Write := Chunk;
         R.Pending_Write_Offset := 1;
         Flush_Write (R, Status);
      end if;
   end Write;

   procedure Flush_Write
     (R      : in out Runtime;
      Status : out Terminal.App.PTY_Write.Write_All_Status) is
   begin
      if R.Current_State /= Active or else R.S = null then
         Status := Terminal.App.PTY_Write.Session_Closed;
      elsif not Has_Pending_Write (R) then
         Status := Terminal.App.PTY_Write.Ok;
      else
         Terminal.App.PTY_Write.Write_Remaining
           (R.S.all, R.Pending_Write, R.Pending_Write_Offset, Status);
         if Status = Terminal.App.PTY_Write.Ok then
            R.Pending_Write := (others => <>);
            R.Pending_Write_Offset := 1;
         elsif Status in
           Terminal.App.PTY_Write.Failed | Terminal.App.PTY_Write.Session_Closed
         then
            R.Current_State := Exited;
         end if;
      end if;
   end Flush_Write;

   function Has_Pending_Write (R : Runtime) return Boolean is
     (R.Pending_Write.Length > 0);

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
      elsif R.Size_Known and then R.Rows = Rows and then R.Cols = Cols then
         Core_Status := Terminal.Core.Ok;
         PTY_Status := Terminal.PTY.Backend.Ok;
      else
         Terminal.Core.Resize (R.T.all, Rows, Cols, Core_Status);
         Terminal.PTY.Backend.Resize (R.S.all, Rows, Cols, PTY_Status);
         if Core_Status = Terminal.Core.Ok
           and then PTY_Status = Terminal.PTY.Backend.Ok
         then
            R.Rows := Rows;
            R.Cols := Cols;
            R.Size_Known := True;
         end if;
      end if;
   end Resize;

   function State (R : Runtime) return Runtime_Status is
     (R.Current_State);

   function Graphics_Stream_ID
     (R : Runtime) return Terminal.Core.Graphics_Stream_ID is
     (R.Stream_ID);

   function Core (R : Runtime) return access Terminal.Core.Terminal is
   begin
      return R.T;
   end Core;

   function PTY_Queue
     (R : Runtime) return access Terminal.App.Queues.PTY_Output_Queue is
   begin
      return R.Q;
   end PTY_Queue;

   function Is_Alive (R : in out Runtime) return Boolean is
   begin
      if R.Current_State /= Active or else R.S = null then
         return False;
      elsif Terminal.PTY.Backend.Is_Alive (R.S.all) then
         return True;
      else
         R.Current_State := Exited;
         return False;
      end if;
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
         when Exited =>
            return "Session runtime exited";
         when Cleanup_Pending =>
            return "Session runtime cleanup pending";
         when Closed =>
            return "Session runtime closed";
      end case;
   end Status_Label;
end Terminal.App.Session_Runtime;
