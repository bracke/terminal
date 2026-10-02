with Terminal.App.Splits;
with Terminal.App.Tabs;

package Terminal.App.Sessions is
   Max_Sessions : constant := Terminal.App.Tabs.Max_Tabs;
   Max_Status_Label_Length : constant := 96;

   subtype Session_Count is Natural range 0 .. Max_Sessions;
   subtype Session_Index is Positive range 1 .. Max_Sessions;

   type Session_Lifecycle is
     (Unused,
      Live,
      Closed);

   type Session_Status is
     (Ok,
      At_Capacity,
      Last_Session,
      Invalid_Index);

   type Session_Lifecycle_Array is array (Session_Index) of Session_Lifecycle;

   type Session_Snapshot is record
      Count  : Session_Count := 0;
      Active : Session_Index := 1;
      States : Session_Lifecycle_Array := (others => Unused);
   end record;

   type Session_Table is private;

   procedure Initialize (Table : out Session_Table);
   procedure New_Session
     (Table  : in out Session_Table;
      Status : out Session_Status);
   procedure Close_Active
     (Table  : in out Session_Table;
      Status : out Session_Status);
   procedure Activate
     (Table  : in out Session_Table;
      Index  : Session_Index;
      Status : out Session_Status);
   procedure Activate_Tab
     (Table  : in out Session_Table;
      Tabs   : in out Terminal.App.Tabs.Tab_State;
      Index  : Terminal.App.Tabs.Tab_Index;
      Status : out Session_Status);
   procedure Activate_Pane
     (Table  : in out Session_Table;
      Splits : in out Terminal.App.Splits.Split_State;
      Index  : Terminal.App.Splits.Pane_Index;
      Status : out Session_Status);

   function Count (Table : Session_Table) return Session_Count;
   function Active (Table : Session_Table) return Session_Index;
   function Lifecycle
     (Table : Session_Table;
      Index : Session_Index) return Session_Lifecycle;
   function Snapshot (Table : Session_Table) return Session_Snapshot;
   function Status_Label (Table : Session_Table) return String;

private
   type Session_Table is record
      Current_Count : Session_Count := 1;
      Active_Index  : Session_Index := 1;
      States        : Session_Lifecycle_Array := (others => Unused);
   end record;
end Terminal.App.Sessions;
