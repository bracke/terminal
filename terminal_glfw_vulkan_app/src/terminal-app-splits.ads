package Terminal.App.Splits is
   Max_Panes : constant := 4;
   Max_Status_Label_Length : constant := 96;
   subtype Pane_Count is Natural range 0 .. Max_Panes;
   subtype Pane_Index is Positive range 1 .. Max_Panes;

   type Split_Command is
     (No_Command,
      Split_Horizontal,
      Split_Vertical,
      Close_Pane,
      Next_Pane);

   type Split_Status is
     (Ok,
      At_Capacity,
      Last_Pane,
      Invalid_Index);

   type Split_Orientation is (Horizontal, Vertical);

   type Pane_Rect is record
      Row  : Positive := 1;
      Col  : Positive := 1;
      Rows : Natural := 0;
      Cols : Natural := 0;
      Active : Boolean := False;
   end record;

   type Pane_Rect_Array is array (Pane_Index) of Pane_Rect;

   type Pane_Layout is record
      Count : Pane_Count := 0;
      Rects : Pane_Rect_Array := (others => <>);
   end record;

   type Split_Snapshot is record
      Count       : Pane_Count := 0;
      Active      : Pane_Index := 1;
      Orientation : Split_Orientation := Horizontal;
   end record;

   type Split_State is private;

   procedure Initialize (State : out Split_State);
   procedure Apply
     (State   : in out Split_State;
      Command : Split_Command;
      Status  : out Split_Status);
   procedure Activate
     (State  : in out Split_State;
      Index  : Pane_Index;
      Status : out Split_Status);
   procedure Activate_At
     (State  : in out Split_State;
      Layout : Pane_Layout;
      Row    : Positive;
      Col    : Positive;
      Status : out Split_Status);
   procedure Close_At
     (State  : in out Split_State;
      Layout : Pane_Layout;
      Row    : Positive;
      Col    : Positive;
      Status : out Split_Status);

   function Count (State : Split_State) return Pane_Count;
   function Active (State : Split_State) return Pane_Index;
   function Snapshot (State : Split_State) return Split_Snapshot;
   function Layout
     (State : Split_State;
      Rows  : Positive;
      Cols  : Positive) return Pane_Layout;
   function Pane_At
     (Layout : Pane_Layout;
      Row    : Positive;
      Col    : Positive) return Pane_Count;
   function Pane_Label (Index : Pane_Index) return String;
   function Fitted_Label
     (Index : Pane_Index;
      Width : Natural) return String;
   function Status_Label (State : Split_State) return String;
   function Title_Suffix (State : Split_State) return String;

private
   type Split_State is record
      Current_Count : Pane_Count := 1;
      Active_Index  : Pane_Index := 1;
      Layout_Axis   : Split_Orientation := Horizontal;
   end record;
end Terminal.App.Splits;
