package Terminal.App.Splits is
   Max_Panes : constant := 4;
   Max_Nodes : constant := Max_Panes * 2 - 1;
   Weight_Unit : constant := 1_024;
   Max_Status_Label_Length : constant := 96;
   subtype Pane_Count is Natural range 0 .. Max_Panes;
   subtype Pane_Index is Positive range 1 .. Max_Panes;
   subtype Divider_Index is Positive range 1 .. Max_Panes - 1;

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
   type Divider_Rect is record
      Row         : Positive := 1;
      Col         : Positive := 1;
      Rows        : Natural := 0;
      Cols        : Natural := 0;
      Region_Row  : Positive := 1;
      Region_Col  : Positive := 1;
      Region_Rows : Natural := 0;
      Region_Cols : Natural := 0;
      Orientation : Split_Orientation := Horizontal;
      Node        : Natural := 0;
   end record;
   type Divider_Rect_Array is array (Divider_Index) of Divider_Rect;

   type Pane_Layout is record
      Count : Pane_Count := 0;
      Rects : Pane_Rect_Array := (others => <>);
      Divider_Count : Natural range 0 .. Max_Panes - 1 := 0;
      Dividers : Divider_Rect_Array := (others => <>);
   end record;

   type Split_Snapshot is record
      Count       : Pane_Count := 0;
      Active      : Pane_Index := 1;
      Orientation : Split_Orientation := Horizontal;
   end record;

   subtype Node_Handle is Natural range 0 .. Max_Nodes;
   subtype Tree_Weight is Positive range 1 .. Weight_Unit - 1;
   type Serialized_Node_Kind is
     (Empty_Tree_Node, Pane_Tree_Node, Branch_Tree_Node);
   type Serialized_Node is record
      Kind         : Serialized_Node_Kind := Empty_Tree_Node;
      Parent       : Node_Handle := 0;
      First        : Node_Handle := 0;
      Second       : Node_Handle := 0;
      Orientation  : Split_Orientation := Horizontal;
      First_Weight : Tree_Weight := Weight_Unit / 2;
      Pane         : Pane_Index := 1;
   end record;
   type Serialized_Node_Array is
     array (Positive range 1 .. Max_Nodes) of Serialized_Node;
   type Split_Tree is record
      Count  : Pane_Count := 0;
      Active : Pane_Index := 1;
      Root   : Node_Handle := 0;
      Nodes  : Serialized_Node_Array := (others => <>);
   end record;

   type Split_State is private;

   procedure Initialize (State : out Split_State);
   procedure Clear (State : out Split_State);
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
   procedure Move_Divider
     (State    : in out Split_State;
      Layout   : Pane_Layout;
      Divider  : Divider_Index;
      Row      : Positive;
      Col      : Positive;
      Status   : out Split_Status);

   function Count (State : Split_State) return Pane_Count;
   function Active (State : Split_State) return Pane_Index;
   function Snapshot (State : Split_State) return Split_Snapshot;
   function Tree (State : Split_State) return Split_Tree;
   procedure Restore
     (State  : out Split_State;
      Value  : Split_Tree;
      Status : out Split_Status);
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
   subtype Node_Index is Positive range 1 .. Max_Nodes;
   subtype Optional_Node_Index is Natural range 0 .. Max_Nodes;
   type Node_Kind is (Unused_Node, Leaf_Node, Branch_Node);
   type Split_Node is record
      Kind         : Node_Kind := Unused_Node;
      Parent       : Optional_Node_Index := 0;
      First        : Optional_Node_Index := 0;
      Second       : Optional_Node_Index := 0;
      Orientation  : Split_Orientation := Horizontal;
      First_Weight : Positive range 1 .. Weight_Unit - 1 := Weight_Unit / 2;
      Pane         : Pane_Index := 1;
   end record;
   type Node_Array is array (Node_Index) of Split_Node;
   type Split_State is record
      Current_Count : Pane_Count := 0;
      Active_Index  : Pane_Index := 1;
      Root          : Optional_Node_Index := 0;
      Nodes         : Node_Array := (others => <>);
   end record;
end Terminal.App.Splits;
