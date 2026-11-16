with Terminal.Common.Status;

package body Terminal.App.Splits is
   function Find_Leaf
     (State : Split_State; Pane : Pane_Index) return Optional_Node_Index is
   begin
      for I in State.Nodes'Range loop
         if State.Nodes (I).Kind = Leaf_Node
           and then State.Nodes (I).Pane = Pane
         then
            return I;
         end if;
      end loop;
      return 0;
   end Find_Leaf;

   function Allocate_Node
     (State : Split_State; Excluding : Optional_Node_Index := 0)
      return Optional_Node_Index is
   begin
      for I in State.Nodes'Range loop
         if I /= Excluding and then State.Nodes (I).Kind = Unused_Node then
            return I;
         end if;
      end loop;
      return 0;
   end Allocate_Node;

   function First_Pane
     (State : Split_State; Node : Optional_Node_Index) return Pane_Index is
   begin
      if Node = 0 or else State.Nodes (Node).Kind = Unused_Node then
         return 1;
      elsif State.Nodes (Node).Kind = Leaf_Node then
         return State.Nodes (Node).Pane;
      else
         return First_Pane (State, State.Nodes (Node).First);
      end if;
   end First_Pane;

   procedure Initialize (State : out Split_State) is
   begin
      State := (others => <>);
      State.Current_Count := 1;
      State.Active_Index := 1;
      State.Root := 1;
      State.Nodes (1) := (Kind => Leaf_Node, Pane => 1, others => <>);
   end Initialize;

   procedure Clear (State : out Split_State) is
   begin
      State := (others => <>);
   end Clear;

   procedure Apply
     (State   : in out Split_State;
      Command : Split_Command;
      Status  : out Split_Status)
   is
      Leaf, First, Second : Optional_Node_Index;
   begin
      case Command is
         when No_Command =>
            Status := Ok;
         when Split_Horizontal | Split_Vertical =>
            if State.Current_Count = 0 then
               Status := Invalid_Index;
               return;
            elsif State.Current_Count = Max_Panes then
               Status := At_Capacity;
               return;
            end if;
            Leaf := Find_Leaf (State, State.Active_Index);
            First := Allocate_Node (State);
            Second := Allocate_Node (State, First);
            if Leaf = 0 or else First = 0 or else Second = 0 then
               Status := At_Capacity;
               return;
            end if;
            declare
               Parent : constant Optional_Node_Index := State.Nodes (Leaf).Parent;
               Old_Pane : constant Pane_Index := State.Nodes (Leaf).Pane;
               New_Pane : constant Pane_Index := Pane_Index (State.Current_Count + 1);
            begin
               State.Nodes (First) :=
                 (Kind => Leaf_Node, Parent => Leaf, Pane => Old_Pane,
                  others => <>);
               State.Nodes (Second) :=
                 (Kind => Leaf_Node, Parent => Leaf, Pane => New_Pane,
                  others => <>);
               State.Nodes (Leaf) :=
                 (Kind => Branch_Node,
                  Parent => Parent,
                  First => First,
                  Second => Second,
                  Orientation =>
                    (if Command = Split_Horizontal then Horizontal else Vertical),
                  First_Weight => Weight_Unit / 2,
                  others => <>);
               State.Current_Count := State.Current_Count + 1;
               State.Active_Index := New_Pane;
               Status := Ok;
            end;
         when Close_Pane =>
            if State.Current_Count = 0 then
               Status := Invalid_Index;
               return;
            elsif State.Current_Count = 1 then
               Status := Last_Pane;
               return;
            end if;
            Leaf := Find_Leaf (State, State.Active_Index);
            if Leaf = 0 or else State.Nodes (Leaf).Parent = 0 then
               Status := Invalid_Index;
               return;
            end if;
            declare
               Closed : constant Pane_Index := State.Active_Index;
               Parent : constant Node_Index := State.Nodes (Leaf).Parent;
               Grand : constant Optional_Node_Index := State.Nodes (Parent).Parent;
               Sibling : constant Node_Index :=
                 (if State.Nodes (Parent).First = Leaf
                  then State.Nodes (Parent).Second else State.Nodes (Parent).First);
               Next_Active : Pane_Index := First_Pane (State, Sibling);
            begin
               State.Nodes (Parent) := State.Nodes (Sibling);
               State.Nodes (Parent).Parent := Grand;
               if State.Nodes (Parent).Kind = Branch_Node then
                  State.Nodes (State.Nodes (Parent).First).Parent := Parent;
                  State.Nodes (State.Nodes (Parent).Second).Parent := Parent;
               end if;
               State.Nodes (Leaf) := (others => <>);
               State.Nodes (Sibling) := (others => <>);
               for I in State.Nodes'Range loop
                  if State.Nodes (I).Kind = Leaf_Node
                    and then State.Nodes (I).Pane > Closed
                  then
                     State.Nodes (I).Pane := State.Nodes (I).Pane - 1;
                  end if;
               end loop;
               if Next_Active > Closed then Next_Active := Next_Active - 1; end if;
               State.Current_Count := State.Current_Count - 1;
               State.Active_Index := Next_Active;
               Status := Ok;
            end;
         when Next_Pane =>
            if State.Current_Count = 0 then
               Status := Invalid_Index;
            else
               State.Active_Index :=
                 (if State.Active_Index = State.Current_Count then 1
                  else State.Active_Index + 1);
               Status := Ok;
            end if;
      end case;
   end Apply;

   procedure Activate
     (State  : in out Split_State;
      Index  : Pane_Index;
      Status : out Split_Status) is
   begin
      if Index > State.Current_Count or else Find_Leaf (State, Index) = 0 then
         Status := Invalid_Index;
      else
         State.Active_Index := Index;
         Status := Ok;
      end if;
   end Activate;

   function Count (State : Split_State) return Pane_Count is
     (State.Current_Count);

   function Active (State : Split_State) return Pane_Index is
     (State.Active_Index);

   function Snapshot (State : Split_State) return Split_Snapshot is
     ((Count => State.Current_Count,
       Active => State.Active_Index,
       Orientation =>
         (if State.Root /= 0 and then State.Nodes (State.Root).Kind = Branch_Node
          then State.Nodes (State.Root).Orientation else Horizontal)));

   function Tree (State : Split_State) return Split_Tree is
      Result : Split_Tree :=
        (Count => State.Current_Count,
         Active => State.Active_Index,
         Root => State.Root,
         others => <>);
   begin
      for I in State.Nodes'Range loop
         Result.Nodes (I) :=
           (Kind =>
              (case State.Nodes (I).Kind is
                  when Unused_Node => Empty_Tree_Node,
                  when Leaf_Node => Pane_Tree_Node,
                  when Branch_Node => Branch_Tree_Node),
            Parent => State.Nodes (I).Parent,
            First => State.Nodes (I).First,
            Second => State.Nodes (I).Second,
            Orientation => State.Nodes (I).Orientation,
            First_Weight => State.Nodes (I).First_Weight,
            Pane => State.Nodes (I).Pane);
      end loop;
      return Result;
   end Tree;

   procedure Restore
     (State  : out Split_State;
      Value  : Split_Tree;
      Status : out Split_Status)
   is
      Seen : array (Positive range 1 .. Max_Nodes) of Boolean :=
        (others => False);
      Pane_Seen : array (Pane_Index) of Boolean := (others => False);
      Used : Natural := 0;
      Valid : Boolean := True;

      procedure Visit (Node : Node_Handle; Parent : Node_Handle) is
         Item : Serialized_Node;
      begin
         if not Valid or else Node = 0 or else Seen (Node) then
            Valid := False;
            return;
         end if;
         Seen (Node) := True;
         Used := Used + 1;
         Item := Value.Nodes (Node);
         if Item.Parent /= Parent then
            Valid := False;
         elsif Item.Kind = Pane_Tree_Node then
            if Item.First /= 0 or else Item.Second /= 0
              or else Item.Pane > Value.Count
              or else Pane_Seen (Item.Pane)
            then
               Valid := False;
            else
               Pane_Seen (Item.Pane) := True;
            end if;
         elsif Item.Kind = Branch_Tree_Node then
            if Item.First = 0 or else Item.Second = 0
              or else Item.First = Item.Second
            then
               Valid := False;
            else
               Visit (Item.First, Node);
               Visit (Item.Second, Node);
            end if;
         else
            Valid := False;
         end if;
      end Visit;
   begin
      State := (others => <>);
      if Value.Count = 0 then
         if Value.Root = 0 then
            Status := Ok;
         else
            Status := Invalid_Index;
         end if;
         return;
      elsif Value.Root = 0 or else Value.Active > Value.Count then
         Status := Invalid_Index;
         return;
      end if;

      Visit (Value.Root, 0);
      if Used /= Natural (Value.Count) * 2 - 1 then
         Valid := False;
      end if;
      for I in 1 .. Value.Count loop
         if not Pane_Seen (I) then Valid := False; end if;
      end loop;
      for I in Value.Nodes'Range loop
         if not Seen (I) and then Value.Nodes (I).Kind /= Empty_Tree_Node then
            Valid := False;
         end if;
      end loop;
      if not Valid then
         Status := Invalid_Index;
         return;
      end if;

      State.Current_Count := Value.Count;
      State.Active_Index := Value.Active;
      State.Root := Value.Root;
      for I in State.Nodes'Range loop
         State.Nodes (I) :=
           (Kind =>
              (case Value.Nodes (I).Kind is
                  when Empty_Tree_Node => Unused_Node,
                  when Pane_Tree_Node => Leaf_Node,
                  when Branch_Tree_Node => Branch_Node),
            Parent => Value.Nodes (I).Parent,
            First => Value.Nodes (I).First,
            Second => Value.Nodes (I).Second,
            Orientation => Value.Nodes (I).Orientation,
            First_Weight => Value.Nodes (I).First_Weight,
            Pane => Value.Nodes (I).Pane);
      end loop;
      Status := Ok;
   end Restore;

   function Layout
     (State : Split_State;
      Rows  : Positive;
      Cols  : Positive) return Pane_Layout
   is
      Result : Pane_Layout := (Count => State.Current_Count, others => <>);

      procedure Place
        (Node : Optional_Node_Index;
         Row, Col : Positive;
         Height, Width : Natural)
      is
         First_Size, Second_Size : Natural;
         Divider : Natural;
         Axis : Split_Orientation;
      begin
         if Node = 0 or else State.Nodes (Node).Kind = Unused_Node then
            return;
         elsif State.Nodes (Node).Kind = Leaf_Node then
            Result.Rects (State.Nodes (Node).Pane) :=
              (Row => Row, Col => Col, Rows => Height, Cols => Width,
               Active => State.Nodes (Node).Pane = State.Active_Index);
            return;
         end if;

         Axis := State.Nodes (Node).Orientation;
         if Axis = Horizontal then
            First_Size :=
              (if Height < 2 then Natural'Max (1, Height)
               else Natural'Max
                 (1, Natural'Min
                   (Height - 1,
                    (Height * State.Nodes (Node).First_Weight + Weight_Unit - 1)
                      / Weight_Unit)));
            Second_Size :=
              (if Height < 2 then Natural'Max (1, Height)
               else Height - First_Size);
         else
            First_Size :=
              (if Width < 2 then Natural'Max (1, Width)
               else Natural'Max
                 (1, Natural'Min
                   (Width - 1,
                    (Width * State.Nodes (Node).First_Weight + Weight_Unit - 1)
                      / Weight_Unit)));
            Second_Size :=
              (if Width < 2 then Natural'Max (1, Width)
               else Width - First_Size);
         end if;
         Result.Divider_Count := Result.Divider_Count + 1;
         Divider := Result.Divider_Count;
         Result.Dividers (Divider) :=
           (Row => (if Axis = Horizontal
                    then Positive'Min (Rows, Row + Natural'Max (1, First_Size) - 1)
                    else Row),
            Col => (if Axis = Vertical
                    then Positive'Min (Cols, Col + Natural'Max (1, First_Size) - 1)
                    else Col),
            Rows => (if Axis = Horizontal then 1 else Height),
            Cols => (if Axis = Vertical then 1 else Width),
            Region_Row => Row, Region_Col => Col,
            Region_Rows => Height, Region_Cols => Width,
            Orientation => Axis, Node => Node);
         Place
           (State.Nodes (Node).First, Row, Col,
            (if Axis = Horizontal then First_Size else Height),
            (if Axis = Vertical then First_Size else Width));
         Place
           (State.Nodes (Node).Second,
            (if Axis = Horizontal
             then Positive'Min (Rows, Row + Natural'Max (1, First_Size)) else Row),
            (if Axis = Vertical
             then Positive'Min (Cols, Col + Natural'Max (1, First_Size)) else Col),
            (if Axis = Horizontal then Second_Size else Height),
            (if Axis = Vertical then Second_Size else Width));
      end Place;
   begin
      if State.Current_Count > 0 then Place (State.Root, 1, 1, Rows, Cols); end if;
      return Result;
   end Layout;

   function Pane_At
     (Layout : Pane_Layout;
      Row    : Positive;
      Col    : Positive) return Pane_Count is
   begin
      for I in 1 .. Layout.Count loop
         declare
            Rect : constant Pane_Rect := Layout.Rects (I);
         begin
            if Rect.Rows > 0 and then Rect.Cols > 0
              and then Row >= Rect.Row and then Row < Rect.Row + Rect.Rows
              and then Col >= Rect.Col and then Col < Rect.Col + Rect.Cols
            then
               return I;
            end if;
         end;
      end loop;
      return 0;
   end Pane_At;

   procedure Activate_At
     (State  : in out Split_State;
      Layout : Pane_Layout;
      Row    : Positive;
      Col    : Positive;
      Status : out Split_Status)
   is
      Hit : constant Pane_Count := Pane_At (Layout, Row, Col);
   begin
      if Hit = 0 then Status := Invalid_Index;
      else Activate (State, Positive (Hit), Status);
      end if;
   end Activate_At;

   procedure Close_At
     (State  : in out Split_State;
      Layout : Pane_Layout;
      Row    : Positive;
      Col    : Positive;
      Status : out Split_Status)
   is
      Hit : constant Pane_Count := Pane_At (Layout, Row, Col);
   begin
      if Hit = 0 then
         Status := Invalid_Index;
      else
         Activate (State, Positive (Hit), Status);
         if Status = Ok then Apply (State, Close_Pane, Status); end if;
      end if;
   end Close_At;

   procedure Move_Divider
     (State    : in out Split_State;
      Layout   : Pane_Layout;
      Divider  : Divider_Index;
      Row      : Positive;
      Col      : Positive;
      Status   : out Split_Status)
   is
      Description : Divider_Rect;
      Extent, Requested : Natural;
      Node : Optional_Node_Index;
   begin
      if Divider > Layout.Divider_Count then
         Status := Invalid_Index;
         return;
      end if;
      Description := Layout.Dividers (Divider);
      Node := Description.Node;
      if Node = 0 or else State.Nodes (Node).Kind /= Branch_Node then
         Status := Invalid_Index;
         return;
      end if;
      if Description.Orientation = Horizontal then
         Extent := Description.Region_Rows;
         Requested :=
           (if Row <= Description.Region_Row then 1
            else Natural (Row) - Description.Region_Row + 1);
      else
         Extent := Description.Region_Cols;
         Requested :=
           (if Col <= Description.Region_Col then 1
            else Natural (Col) - Description.Region_Col + 1);
      end if;
      if Extent < 2 then
         Status := Invalid_Index;
         return;
      end if;
      Requested := Natural'Max (1, Natural'Min (Extent - 1, Requested));
      State.Nodes (Node).First_Weight := Positive
        (Natural'Max
           (1, Natural'Min (Weight_Unit - 1, Requested * Weight_Unit / Extent)));
      Status := Ok;
   end Move_Divider;

   function Trim_Image (Value : Natural) return String
      renames Terminal.Common.Status.Trimmed_Natural;

   function Pane_Label (Index : Pane_Index) return String is
     ("Pane " & Trim_Image (Index));

   function Fitted_Label
     (Index : Pane_Index;
      Width : Natural) return String
   is
      Text : constant String := Pane_Label (Index);
   begin
      if Width = 0 then return "";
      elsif Text'Length <= Width then return Text;
      elsif Width <= 3 then return Text (Text'First .. Text'First + Width - 1);
      else return Text (Text'First .. Text'First + Width - 4) & "...";
      end if;
   end Fitted_Label;

   function Status_Label (State : Split_State) return String is
   begin
      if State.Current_Count = 0 then return "No live panes";
      elsif State.Current_Count = 1 then return "Single live pane";
      else return "Live split panes=" & Trim_Image (State.Current_Count)
        & " active=" & Trim_Image (State.Active_Index);
      end if;
   end Status_Label;

   function Title_Suffix (State : Split_State) return String is
     (if State.Current_Count <= 1 then ""
      else " pane " & Trim_Image (State.Active_Index) & "/"
        & Trim_Image (State.Current_Count));
end Terminal.App.Splits;
