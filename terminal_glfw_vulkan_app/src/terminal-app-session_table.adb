with Ada.Unchecked_Deallocation;

package body Terminal.App.Session_Table is
   use type Terminal.App.Session_Runtime.Runtime_Status;
   use type Terminal.App.Session_Runtime.Start_Status;
   use type Terminal.App.Sessions.Session_Status;
   use type Terminal.App.Splits.Split_Command;
   use type Terminal.App.Splits.Split_Status;
   use type Terminal.App.Tabs.Tab_Status;

   procedure Free_Runtime is new Ada.Unchecked_Deallocation
     (Terminal.App.Session_Runtime.Runtime,
      Runtime_Access);

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

   procedure Start_Runtime
     (Slot             : in out Runtime_Access;
      Rows             : Positive;
      Cols             : Positive;
      Scrollback_Limit : Natural;
      Status           : out Table_Status;
      Start_Status     : out Terminal.App.Session_Runtime.Start_Status)
   is
   begin
      Slot := new Terminal.App.Session_Runtime.Runtime;
      Terminal.App.Session_Runtime.Start
        (Slot.all, Rows, Cols, Scrollback_Limit, Start_Status);
      if Start_Status = Terminal.App.Session_Runtime.Ok then
         Status := Ok;
      else
         Status := Start_Failed;
         Terminal.App.Session_Runtime.Close (Slot.all);
         Free_Runtime (Slot);
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
      Status           : out Table_Status)
   is
   begin
      Close_All (Table);
      Terminal.App.Sessions.Initialize (Table.Sessions);
      Start_Runtime
        (Table.Runtimes (1),
         Rows,
         Cols,
         Scrollback_Limit,
         Status,
         Table.Last_Start);
   end Initialize;

   procedure New_Tab
     (Table            : in out Runtime_Table;
      Tabs             : in out Terminal.App.Tabs.Tab_State;
      Rows             : Positive;
      Cols             : Positive;
      Scrollback_Limit : Natural;
      Status           : out Table_Status)
   is
      Session_Status : Terminal.App.Sessions.Session_Status;
      Tab_Status : Terminal.App.Tabs.Tab_Status;
      New_Index : Terminal.App.Sessions.Session_Index;
   begin
      Terminal.App.Sessions.New_Session (Table.Sessions, Session_Status);
      if Session_Status /= Terminal.App.Sessions.Ok then
         Status := Convert (Session_Status);
         return;
      end if;

      New_Index := Terminal.App.Sessions.Active (Table.Sessions);
      Start_Runtime
        (Table.Runtimes (New_Index),
         Rows,
         Cols,
         Scrollback_Limit,
         Status,
         Table.Last_Start);
      if Status /= Ok then
         Terminal.App.Sessions.Close_Active (Table.Sessions, Session_Status);
         return;
      end if;

      Terminal.App.Tabs.Apply (Tabs, Terminal.App.Tabs.New_Tab, Tab_Status);
      if Tab_Status /= Terminal.App.Tabs.Ok then
         Terminal.App.Session_Runtime.Close (Table.Runtimes (New_Index).all);
         Free_Runtime (Table.Runtimes (New_Index));
         Terminal.App.Sessions.Close_Active (Table.Sessions, Session_Status);
         Status := Invalid_Index;
      end if;
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
   begin
      if Terminal.App.Sessions.Count (Table.Sessions) <= 1 then
         Status := Last_Session;
         return;
      end if;

      if Table.Runtimes (Index) /= null then
         Terminal.App.Session_Runtime.Close (Table.Runtimes (Index).all);
         Free_Runtime (Table.Runtimes (Index));
      end if;

      Terminal.App.Sessions.Close_Active (Table.Sessions, Session_Status);
      if Session_Status /= Terminal.App.Sessions.Ok then
         Status := Convert (Session_Status);
         return;
      end if;

      if Index < Terminal.App.Sessions.Session_Index'Last then
         for I in Index .. Terminal.App.Sessions.Session_Index'Last - 1 loop
            Table.Runtimes (I) := Table.Runtimes (I + 1);
         end loop;
         Table.Runtimes (Terminal.App.Sessions.Session_Index'Last) := null;
      end if;
      Terminal.App.Tabs.Apply (Tabs, Terminal.App.Tabs.Close_Tab, Tab_Status);
      Status := (if Tab_Status = Terminal.App.Tabs.Ok then Ok else Invalid_Index);
   end Close_Tab;

   procedure Split_Pane
     (Table            : in out Runtime_Table;
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
   begin
      if Command /= Terminal.App.Splits.Split_Horizontal
        and then Command /= Terminal.App.Splits.Split_Vertical
      then
         Status := Invalid_Index;
         return;
      end if;

      if Terminal.App.Splits.Count (Splits) >= Terminal.App.Splits.Max_Panes then
         Status := At_Capacity;
         return;
      end if;

      Terminal.App.Sessions.New_Session (Table.Sessions, Session_Status);
      if Session_Status /= Terminal.App.Sessions.Ok then
         Status := Convert (Session_Status);
         return;
      end if;

      New_Index := Terminal.App.Sessions.Active (Table.Sessions);
      Start_Runtime
        (Table.Runtimes (New_Index),
         Rows,
         Cols,
         Scrollback_Limit,
         Status,
         Table.Last_Start);
      if Status /= Ok then
         Terminal.App.Sessions.Close_Active (Table.Sessions, Session_Status);
         return;
      end if;

      Terminal.App.Splits.Apply (Splits, Command, Split_Status);
      if Split_Status /= Terminal.App.Splits.Ok then
         Terminal.App.Session_Runtime.Close (Table.Runtimes (New_Index).all);
         Free_Runtime (Table.Runtimes (New_Index));
         Terminal.App.Sessions.Close_Active (Table.Sessions, Session_Status);
         Status := Invalid_Index;
      end if;
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
   begin
      if Terminal.App.Sessions.Count (Table.Sessions) <= 1 then
         Status := Last_Session;
         return;
      end if;

      if Table.Runtimes (Index) /= null then
         Terminal.App.Session_Runtime.Close (Table.Runtimes (Index).all);
         Free_Runtime (Table.Runtimes (Index));
      end if;

      Terminal.App.Sessions.Close_Active (Table.Sessions, Session_Status);
      if Session_Status /= Terminal.App.Sessions.Ok then
         Status := Convert (Session_Status);
         return;
      end if;

      if Index < Terminal.App.Sessions.Session_Index'Last then
         for I in Index .. Terminal.App.Sessions.Session_Index'Last - 1 loop
            Table.Runtimes (I) := Table.Runtimes (I + 1);
         end loop;
         Table.Runtimes (Terminal.App.Sessions.Session_Index'Last) := null;
      end if;
      Terminal.App.Splits.Apply
        (Splits, Terminal.App.Splits.Close_Pane, Split_Status);
      Status :=
        (if Split_Status = Terminal.App.Splits.Ok then Ok else Invalid_Index);
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
      for I in Table.Runtimes'Range loop
         if Table.Runtimes (I) /= null then
            Terminal.App.Session_Runtime.Close (Table.Runtimes (I).all);
            Free_Runtime (Table.Runtimes (I));
         end if;
      end loop;
      Terminal.App.Sessions.Initialize (Table.Sessions);
   end Close_All;
end Terminal.App.Session_Table;
