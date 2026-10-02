with Terminal.App.Session_Runtime;
with Terminal.App.Sessions;
with Terminal.App.Splits;
with Terminal.App.Tabs;

package Terminal.App.Session_Table is
   Max_Status_Label_Length : constant := 96;

   type Table_Status is
     (Ok,
      Start_Failed,
      At_Capacity,
      Last_Session,
      Invalid_Index);

   type Runtime_Table is limited private;

   procedure Initialize
     (Table            : in out Runtime_Table;
      Rows             : Positive;
      Cols             : Positive;
      Scrollback_Limit : Natural;
      Status           : out Table_Status);

   procedure New_Tab
     (Table            : in out Runtime_Table;
      Tabs             : in out Terminal.App.Tabs.Tab_State;
      Rows             : Positive;
      Cols             : Positive;
      Scrollback_Limit : Natural;
      Status           : out Table_Status);

   procedure Close_Tab
     (Table  : in out Runtime_Table;
      Tabs   : in out Terminal.App.Tabs.Tab_State;
      Status : out Table_Status);

   procedure Split_Pane
     (Table            : in out Runtime_Table;
      Splits           : in out Terminal.App.Splits.Split_State;
      Command          : Terminal.App.Splits.Split_Command;
      Rows             : Positive;
      Cols             : Positive;
      Scrollback_Limit : Natural;
      Status           : out Table_Status);

   procedure Close_Pane
     (Table  : in out Runtime_Table;
      Splits : in out Terminal.App.Splits.Split_State;
      Status : out Table_Status);

   procedure Activate
     (Table  : in out Runtime_Table;
      Index  : Terminal.App.Sessions.Session_Index;
      Status : out Table_Status);

   function Count (Table : Runtime_Table) return Terminal.App.Sessions.Session_Count;
   function Active (Table : Runtime_Table) return Terminal.App.Sessions.Session_Index;
   function Active_Runtime
     (Table : Runtime_Table)
      return access Terminal.App.Session_Runtime.Runtime;
   function Runtime_At
     (Table : Runtime_Table;
      Index : Terminal.App.Sessions.Session_Index)
      return access Terminal.App.Session_Runtime.Runtime;
   function Status_Label (Table : Runtime_Table) return String;

   procedure Close_All (Table : in out Runtime_Table);

private
   type Runtime_Access is access all Terminal.App.Session_Runtime.Runtime;
   type Runtime_Array is
     array (Terminal.App.Sessions.Session_Index) of Runtime_Access;

   type Runtime_Table is limited record
      Sessions : Terminal.App.Sessions.Session_Table;
      Runtimes : Runtime_Array := (others => null);
      Last_Start : Terminal.App.Session_Runtime.Start_Status :=
        Terminal.App.Session_Runtime.Allocation_Failed;
   end record;
end Terminal.App.Session_Table;
