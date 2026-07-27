package Terminal.App.Tabs is
   Max_Tabs : constant := 8;
   Max_Status_Label_Length : constant := 96;
   subtype Tab_Count is Natural range 0 .. Max_Tabs;
   subtype Tab_Index is Positive range 1 .. Max_Tabs;
   Max_Tab_Label_Length : constant := 32;
   subtype Tab_Label_Length is Natural range 0 .. Max_Tab_Label_Length;
   subtype Tab_Label_Index is Positive range 1 .. Max_Tab_Label_Length;

   type Tab_Label is record
      Length : Tab_Label_Length := 0;
      Text   : String (Tab_Label_Index) := (others => ' ');
   end record;

   type Tab_Label_Array is array (Tab_Index) of Tab_Label;

   Min_Tab_Width : constant := 6;

   type Tab_Rect is record
      Col   : Positive := 1;
      Width : Natural := 0;
      Active : Boolean := False;
   end record;

   type Tab_Rect_Array is array (Tab_Index) of Tab_Rect;

   type Tab_Layout is record
      Count : Tab_Count := 0;
      Rects : Tab_Rect_Array := (others => <>);
   end record;

   type Tab_Snapshot is record
      Count  : Tab_Count := 0;
      Active : Tab_Index := 1;
      Labels : Tab_Label_Array := (others => <>);
   end record;

   type Tab_Command is
     (No_Command,
      New_Tab,
      Close_Tab,
      Next_Tab,
      Previous_Tab);

   type Tab_Status is
     (Ok,
      At_Capacity,
      Last_Tab,
      Invalid_Index);

   type Tab_State is private;

   procedure Initialize (State : out Tab_State);
   procedure Apply
     (State  : in out Tab_State;
      Command : Tab_Command;
      Status  : out Tab_Status);
   procedure Activate
     (State  : in out Tab_State;
      Index  : Tab_Index;
      Status : out Tab_Status);
   procedure Set_Label
     (State : in out Tab_State;
      Index : Tab_Index;
      Text  : String;
      Status : out Tab_Status);
   procedure Activate_At
     (State  : in out Tab_State;
      Layout : Tab_Layout;
      Col    : Positive;
      Status : out Tab_Status);
   procedure Close_At
     (State  : in out Tab_State;
      Layout : Tab_Layout;
      Col    : Positive;
      Status : out Tab_Status);

   function Count (State : Tab_State) return Tab_Count;
   function Active (State : Tab_State) return Tab_Index;
   function Snapshot (State : Tab_State) return Tab_Snapshot;
   function Label
     (State : Tab_State;
      Index : Tab_Index) return Tab_Label;
   function Label_Text (Label : Tab_Label) return String;
   function Fitted_Label
     (Label : Tab_Label;
      Width : Natural) return String;
   function Layout
     (State : Tab_State;
      Cols  : Positive) return Tab_Layout;
   function Tab_At
     (Layout : Tab_Layout;
      Col    : Positive) return Tab_Count;
   function Status_Label (State : Tab_State) return String;
   function Title_Suffix (State : Tab_State) return String;

private
   type Tab_State is record
      Current_Count : Tab_Count := 1;
      Active_Index  : Tab_Index := 1;
      Labels        : Tab_Label_Array := (others => <>);
   end record;
end Terminal.App.Tabs;
