with Ada.Exceptions;
with Ada.Unchecked_Deallocation;
with Terminal.App.Cleanup_Diagnostics;
with Terminal.App.PTY_Write;

package body Terminal.App.Session_Table is
   use type Terminal.App.PTY_Write.Write_All_Status;
   use type Terminal.App.Session_Runtime.Runtime_Status;
   use type Terminal.App.Session_Runtime.Start_Status;
   use type Terminal.App.Sessions.Session_Status;
   use type Terminal.App.Splits.Split_Command;
   use type Terminal.App.Splits.Split_Status;
   use type Terminal.App.Tabs.Tab_Status;

   procedure Free_Runtime is new Ada.Unchecked_Deallocation
     (Terminal.App.Session_Runtime.Runtime,
      Runtime_Access);

   procedure Release_Runtime (Slot : in out Runtime_Access) is
   begin
      if Slot /= null then
         Terminal.App.Session_Runtime.Close (Slot.all);
         if Terminal.App.Session_Runtime.State (Slot.all) /=
           Terminal.App.Session_Runtime.Closed
         then
            raise Program_Error with "session runtime cleanup is incomplete";
         end if;
         Free_Runtime (Slot);
      end if;
   end Release_Runtime;

   procedure Close_All_Internal
     (Table        : in out Runtime_Table;
      Raise_Errors : Boolean)
   is
      First_Error : Ada.Exceptions.Exception_Occurrence;
      Failed      : Boolean := False;
      Have_Error  : Boolean := False;
   begin
      --  Do not free individual slots until every runtime is closed.  On a
      --  partial failure the logical session table and runtime indices must
      --  continue to describe the same objects so cleanup can be retried.
      for I in Table.Runtimes'Range loop
         if Table.Runtimes (I) /= null then
            begin
               Terminal.App.Session_Runtime.Close (Table.Runtimes (I).all);
               Failed := Failed or else
                 Terminal.App.Session_Runtime.State (Table.Runtimes (I).all) /=
                   Terminal.App.Session_Runtime.Closed;
            exception
               when Error : others =>
                  if not Have_Error then
                     Ada.Exceptions.Save_Occurrence (First_Error, Error);
                     Have_Error := True;
                  end if;
                  Failed := True;
            end;
         end if;
      end loop;

      if Failed then
         if Raise_Errors then
            if Have_Error then
               Ada.Exceptions.Reraise_Occurrence (First_Error);
            else
               raise Program_Error with
                 "one or more session runtimes remain owned";
            end if;
         end if;
         return;
      end if;

      for I in Table.Runtimes'Range loop
         if Table.Runtimes (I) /= null then
            Free_Runtime (Table.Runtimes (I));
         end if;
      end loop;
      Terminal.App.Sessions.Initialize (Table.Sessions);
   end Close_All_Internal;

   function Convert
     (Status : Terminal.App.Sessions.Session_Status) return Table_Status is
   begin
      case Status is
         when Terminal.App.Sessions.Ok =>
            return Ok;
         when Terminal.App.Sessions.At_Capacity =>
            return At_Capacity;
         when Terminal.App.Sessions.Last_Session =>
            return Last_Session;
         when Terminal.App.Sessions.Invalid_Index =>
            return Invalid_Index;
      end case;
   end Convert;

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

   procedure Start_Runtime
     (Slot             : in out Runtime_Access;
      Rows             : Positive;
      Cols             : Positive;
      Scrollback_Limit : Natural;
      Graphics_Profile : Terminal.Core.Graphics_Capability_Profile;
      Status           : out Table_Status;
      Start_Status     : out Terminal.App.Session_Runtime.Start_Status)
   is
   begin
      Slot := new Terminal.App.Session_Runtime.Runtime;
      Terminal.App.Session_Runtime.Start
        (Slot.all,
         Rows,
         Cols,
         Scrollback_Limit,
         Start_Status,
         Graphics_Profile);
      if Start_Status = Terminal.App.Session_Runtime.Ok then
         Status := Ok;
      else
         Status := Start_Failed;
         Release_Runtime (Slot);
      end if;
   exception
      when Storage_Error =>
         Status := Start_Failed;
         Start_Status := Terminal.App.Session_Runtime.Allocation_Failed;
   end Start_Runtime;

   procedure Initialize
     (Table            : in out Runtime_Table;
      Rows             : Positive;
      Cols             : Positive;
      Scrollback_Limit : Natural;
      Status           : out Table_Status;
      Graphics_Profile : Terminal.Core.Graphics_Capability_Profile :=
        Terminal.App.Core_Graphics_Profile)
   is
   begin
      Close_All (Table);
      Table.Graphics_Profile := Graphics_Profile;
      Terminal.App.Sessions.Initialize (Table.Sessions);
      Start_Runtime
        (Table.Runtimes (1),
         Rows,
         Cols,
         Scrollback_Limit,
         Table.Graphics_Profile,
         Status,
         Table.Last_Start);
   end Initialize;

   procedure New_Tab
     (Table            : in out Runtime_Table;
      Tabs             : in out Terminal.App.Tabs.Tab_State;
      Splits           : Terminal.App.Splits.Split_State;
      Rows             : Positive;
      Cols             : Positive;
      Scrollback_Limit : Natural;
      Status           : out Table_Status)
   is
      Session_Status : Terminal.App.Sessions.Session_Status;
      Tab_Status : Terminal.App.Tabs.Tab_Status;
      New_Index : Terminal.App.Sessions.Session_Index;
      Next_Sessions : Terminal.App.Sessions.Session_Table := Table.Sessions;
      Next_Tabs : Terminal.App.Tabs.Tab_State := Tabs;
   begin
      if Terminal.App.Splits.Count (Splits) > 1 then
         Status := Layout_Conflict;
         return;
      end if;
      Terminal.App.Tabs.Apply
        (Next_Tabs, Terminal.App.Tabs.New_Tab, Tab_Status);
      if Tab_Status /= Terminal.App.Tabs.Ok then
         Status :=
           (if Tab_Status = Terminal.App.Tabs.At_Capacity
            then At_Capacity else Invalid_Index);
         return;
      end if;
      Terminal.App.Sessions.New_Session (Next_Sessions, Session_Status);
      if Session_Status /= Terminal.App.Sessions.Ok then
         Status := Convert (Session_Status);
         return;
      end if;

      New_Index := Terminal.App.Sessions.Active (Next_Sessions);
      Start_Runtime
        (Table.Runtimes (New_Index),
         Rows,
         Cols,
         Scrollback_Limit,
         Table.Graphics_Profile,
         Status,
         Table.Last_Start);
      if Status /= Ok then
         return;
      end if;
      Table.Sessions := Next_Sessions;
      Tabs := Next_Tabs;
   end New_Tab;

   procedure Close_Tab
     (Table  : in out Runtime_Table;
      Tabs   : in out Terminal.App.Tabs.Tab_State;
      Status : out Table_Status)
   is
      Index : constant Terminal.App.Sessions.Session_Index :=
        Terminal.App.Sessions.Active (Table.Sessions);
      Session_Status : Terminal.App.Sessions.Session_Status;
      Tab_Status : Terminal.App.Tabs.Tab_Status;
      Next_Sessions : Terminal.App.Sessions.Session_Table := Table.Sessions;
      Next_Tabs : Terminal.App.Tabs.Tab_State := Tabs;
   begin
      if Terminal.App.Sessions.Count (Table.Sessions) <= 1 then
         Status := Last_Session;
         return;
      end if;

      Terminal.App.Sessions.Close_Active (Next_Sessions, Session_Status);
      if Session_Status /= Terminal.App.Sessions.Ok then
         Status := Convert (Session_Status);
         return;
      end if;
      Terminal.App.Tabs.Apply
        (Next_Tabs, Terminal.App.Tabs.Close_Tab, Tab_Status);
      if Tab_Status /= Terminal.App.Tabs.Ok then
         Status := Invalid_Index;
         return;
      end if;

      if Table.Runtimes (Index) /= null then
         Release_Runtime (Table.Runtimes (Index));
      end if;

      if Index < Terminal.App.Sessions.Session_Index'Last then
         for I in Index .. Terminal.App.Sessions.Session_Index'Last - 1 loop
            Table.Runtimes (I) := Table.Runtimes (I + 1);
         end loop;
         Table.Runtimes (Terminal.App.Sessions.Session_Index'Last) := null;
      end if;
      Table.Sessions := Next_Sessions;
      Tabs := Next_Tabs;
      Status := Ok;
   end Close_Tab;

   procedure Split_Pane
     (Table            : in out Runtime_Table;
      Tabs             : Terminal.App.Tabs.Tab_State;
      Splits           : in out Terminal.App.Splits.Split_State;
      Command          : Terminal.App.Splits.Split_Command;
      Rows             : Positive;
      Cols             : Positive;
      Scrollback_Limit : Natural;
      Status           : out Table_Status)
   is
      Session_Status : Terminal.App.Sessions.Session_Status;
      Split_Status : Terminal.App.Splits.Split_Status;
      New_Index : Terminal.App.Sessions.Session_Index;
      Next_Sessions : Terminal.App.Sessions.Session_Table := Table.Sessions;
      Next_Splits : Terminal.App.Splits.Split_State := Splits;
   begin
      if Terminal.App.Tabs.Count (Tabs) > 1 then
         Status := Layout_Conflict;
         return;
      end if;
      if Command /= Terminal.App.Splits.Split_Horizontal
        and then Command /= Terminal.App.Splits.Split_Vertical
      then
         Status := Invalid_Index;
         return;
      end if;

      if (Command = Terminal.App.Splits.Split_Horizontal
          and then Rows <= Positive (Terminal.App.Splits.Count (Splits)))
        or else
          (Command = Terminal.App.Splits.Split_Vertical
           and then Cols <= Positive (Terminal.App.Splits.Count (Splits)))
      then
         Status := Insufficient_Space;
         return;
      end if;

      if Terminal.App.Splits.Count (Splits) >= Terminal.App.Splits.Max_Panes then
         Status := At_Capacity;
         return;
      end if;

      Terminal.App.Splits.Apply (Next_Splits, Command, Split_Status);
      if Split_Status /= Terminal.App.Splits.Ok then
         Status :=
           (if Split_Status = Terminal.App.Splits.At_Capacity
            then At_Capacity else Invalid_Index);
         return;
      end if;
      Terminal.App.Sessions.New_Session (Next_Sessions, Session_Status);
      if Session_Status /= Terminal.App.Sessions.Ok then
         Status := Convert (Session_Status);
         return;
      end if;

      New_Index := Terminal.App.Sessions.Active (Next_Sessions);
      Start_Runtime
        (Table.Runtimes (New_Index),
         Rows,
         Cols,
         Scrollback_Limit,
         Table.Graphics_Profile,
         Status,
         Table.Last_Start);
      if Status /= Ok then
         return;
      end if;
      Table.Sessions := Next_Sessions;
      Splits := Next_Splits;
   end Split_Pane;

   procedure Close_Pane
     (Table  : in out Runtime_Table;
      Splits : in out Terminal.App.Splits.Split_State;
      Status : out Table_Status)
   is
      Index : constant Terminal.App.Sessions.Session_Index :=
        Terminal.App.Sessions.Active (Table.Sessions);
      Session_Status : Terminal.App.Sessions.Session_Status;
      Split_Status : Terminal.App.Splits.Split_Status;
      Next_Sessions : Terminal.App.Sessions.Session_Table := Table.Sessions;
      Next_Splits : Terminal.App.Splits.Split_State := Splits;
   begin
      if Terminal.App.Sessions.Count (Table.Sessions) <= 1 then
         Status := Last_Session;
         return;
      end if;

      Terminal.App.Sessions.Close_Active (Next_Sessions, Session_Status);
      if Session_Status /= Terminal.App.Sessions.Ok then
         Status := Convert (Session_Status);
         return;
      end if;
      Terminal.App.Splits.Apply
        (Next_Splits, Terminal.App.Splits.Close_Pane, Split_Status);
      if Split_Status /= Terminal.App.Splits.Ok then
         Status := Invalid_Index;
         return;
      end if;

      if Table.Runtimes (Index) /= null then
         Release_Runtime (Table.Runtimes (Index));
      end if;

      if Index < Terminal.App.Sessions.Session_Index'Last then
         for I in Index .. Terminal.App.Sessions.Session_Index'Last - 1 loop
            Table.Runtimes (I) := Table.Runtimes (I + 1);
         end loop;
         Table.Runtimes (Terminal.App.Sessions.Session_Index'Last) := null;
      end if;
      Table.Sessions := Next_Sessions;
      Splits := Next_Splits;
      Status := Ok;
   end Close_Pane;

   procedure Activate
     (Table  : in out Runtime_Table;
      Index  : Terminal.App.Sessions.Session_Index;
      Status : out Table_Status)
   is
      Session_Status : Terminal.App.Sessions.Session_Status;
   begin
      Terminal.App.Sessions.Activate (Table.Sessions, Index, Session_Status);
      Status := Convert (Session_Status);
   end Activate;

   function Count (Table : Runtime_Table) return Terminal.App.Sessions.Session_Count is
     (Terminal.App.Sessions.Count (Table.Sessions));

   function Active (Table : Runtime_Table) return Terminal.App.Sessions.Session_Index is
     (Terminal.App.Sessions.Active (Table.Sessions));

   function Active_Runtime
     (Table : Runtime_Table)
      return access Terminal.App.Session_Runtime.Runtime
   is
   begin
      return Table.Runtimes (Terminal.App.Sessions.Active (Table.Sessions));
   end Active_Runtime;

   function Runtime_At
     (Table : Runtime_Table;
      Index : Terminal.App.Sessions.Session_Index)
      return access Terminal.App.Session_Runtime.Runtime
   is
   begin
      return Table.Runtimes (Index);
   end Runtime_At;

   procedure Poll_Output
     (Table        : in out Runtime_Table;
      Had_Output   : out Runtime_Output_Set;
      Feed_Status  : out Terminal.Core.Feed_Status;
      Write_Status : out Terminal.App.PTY_Write.Write_All_Status)
   is
      Runtime_Feed   : Terminal.Core.Feed_Status;
      Runtime_Write  : Terminal.App.PTY_Write.Write_All_Status;
      Runtime_Output : Boolean;
   begin
      Had_Output := (others => False);
      Feed_Status := Terminal.Core.Ok;
      Write_Status := Terminal.App.PTY_Write.Ok;
      for I in 1 .. Count (Table) loop
         if Table.Runtimes (I) /= null then
            Terminal.App.Session_Runtime.Poll_Output
              (Table.Runtimes (I).all,
               Runtime_Feed,
               Runtime_Write,
               Runtime_Output);
            Had_Output (I) := Runtime_Output;
            if Runtime_Output
              and then Feed_Rank (Runtime_Feed) > Feed_Rank (Feed_Status)
            then
               Feed_Status := Runtime_Feed;
            end if;
            if Runtime_Write in
              Terminal.App.PTY_Write.Failed
                | Terminal.App.PTY_Write.Session_Closed
            then
               Write_Status := Runtime_Write;
            elsif Runtime_Write = Terminal.App.PTY_Write.Incomplete
              and then Write_Status = Terminal.App.PTY_Write.Ok
            then
               Write_Status := Runtime_Write;
            end if;
         end if;
      end loop;
   end Poll_Output;

   function Status_Label (Table : Runtime_Table) return String is
   begin
      if Count (Table) = 0 then
         return "Runtime table inactive";
      else
         return
           "Runtime table sessions="
           & Trim_Image (Count (Table))
           & " active="
           & Trim_Image (Active (Table));
      end if;
   end Status_Label;

   procedure Close_All (Table : in out Runtime_Table) is
   begin
      Close_All_Internal (Table, Raise_Errors => True);
   end Close_All;

   overriding procedure Finalize (Table : in out Runtime_Table) is
   begin
      Close_All_Internal (Table, Raise_Errors => False);
      for Slot of Table.Runtimes loop
         if Slot /= null then
            Terminal.App.Cleanup_Diagnostics.Note_Failure
              (Terminal.App.Cleanup_Diagnostics.Session_Table);
            exit;
         end if;
      end loop;
   exception
      --  A finalizer is a last-resort cleanup path and must not mask the
      --  exception that caused its enclosing scope to unwind.
      when others =>
         Terminal.App.Cleanup_Diagnostics.Note_Failure
           (Terminal.App.Cleanup_Diagnostics.Session_Table);
   end Finalize;
end Terminal.App.Session_Table;
