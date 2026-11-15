with Terminal.Common.Status;

package body Terminal.App.Splits is
   procedure Initialize (State : out Split_State) is
   begin
      State :=
        (Current_Count => 1,
         Active_Index  => 1,
         Layout_Axis   => Horizontal,
         Weights       => (others => Weight_Unit));
   end Initialize;

   procedure Clear (State : out Split_State) is
   begin
      State :=
        (Current_Count => 0,
         Active_Index  => 1,
         Layout_Axis   => Horizontal,
         Weights       => (others => Weight_Unit));
   end Clear;

   procedure Apply
     (State   : in out Split_State;
      Command : Split_Command;
      Status  : out Split_Status)
   is
   begin
      case Command is
         when No_Command =>
            Status := Ok;
         when Split_Horizontal | Split_Vertical =>
            if State.Current_Count = Max_Panes then
               Status := At_Capacity;
            else
               if State.Current_Count <= 1 then
                  State.Layout_Axis :=
                    (if Command = Split_Horizontal
                     then Horizontal
                     else Vertical);
               end if;
               State.Current_Count := State.Current_Count + 1;
               State.Active_Index := State.Current_Count;
               for I in 1 .. State.Current_Count loop
                  State.Weights (I) := Weight_Unit;
               end loop;
               Status := Ok;
            end if;
         when Close_Pane =>
            if State.Current_Count = 0 then
               Status := Invalid_Index;
            elsif State.Current_Count = 1 then
               Status := Last_Pane;
            else
               if State.Active_Index < State.Current_Count then
                  for I in State.Active_Index .. State.Current_Count - 1 loop
                     State.Weights (I) := State.Weights (I + 1);
                  end loop;
               end if;
               State.Weights (State.Current_Count) := Weight_Unit;
               State.Current_Count := State.Current_Count - 1;
               if State.Active_Index > State.Current_Count then
                  State.Active_Index := State.Current_Count;
               end if;
               if State.Current_Count = 1 then
                  State.Layout_Axis := Horizontal;
               end if;
               Status := Ok;
            end if;
         when Next_Pane =>
            if State.Current_Count = 0 then
               Status := Invalid_Index;
               return;
            elsif State.Active_Index = State.Current_Count then
               State.Active_Index := 1;
            else
               State.Active_Index := State.Active_Index + 1;
            end if;
            Status := Ok;
      end case;
   end Apply;

   procedure Activate
     (State  : in out Split_State;
      Index  : Pane_Index;
      Status : out Split_Status)
   is
   begin
      if Index > State.Current_Count then
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
     ((Count       => State.Current_Count,
       Active      => State.Active_Index,
       Orientation => State.Layout_Axis));

   function Layout
     (State : Split_State;
      Rows  : Positive;
      Cols  : Positive) return Pane_Layout
   is
      Result : Pane_Layout := (Count => State.Current_Count, Rects => (others => <>));
      Cursor : Positive := 1;
      Remaining_Extent : Natural :=
        (if State.Layout_Axis = Horizontal then Rows else Cols);
      Remaining_Weight : Natural := 0;
   begin
      if State.Current_Count = 0 then
         return Result;
      end if;

      declare
         Count : constant Positive := Positive (State.Current_Count);
      begin
      for I in 1 .. State.Current_Count loop
         Remaining_Weight := Remaining_Weight + State.Weights (I);
      end loop;
      for I in 1 .. State.Current_Count loop
         declare
            Panes_Left : constant Natural := Count - Natural (I) + 1;
            Size : constant Natural :=
              (if I = State.Current_Count
               then Natural'Max (1, Remaining_Extent)
               elsif Remaining_Extent <= Panes_Left
               then 1
               else Natural'Max
                 (1,
                  Natural'Min
                    (Remaining_Extent - (Panes_Left - 1),
                     (Remaining_Extent * State.Weights (I)
                        + Remaining_Weight - 1)
                       / Remaining_Weight)));
         begin
            if State.Layout_Axis = Horizontal then
               Result.Rects (I) :=
                 (Row  => Positive'Min (Cursor, Rows),
                  Col  => 1,
                  Rows => Size,
                  Cols => Cols,
                  Active => I = State.Active_Index);
            else
               Result.Rects (I) :=
                 (Row  => 1,
                  Col  => Positive'Min (Cursor, Cols),
                  Rows => Rows,
                  Cols => Size,
                  Active => I = State.Active_Index);
            end if;

            if Size > 0 then
               Cursor := Cursor + Size;
            end if;
            Remaining_Extent := Remaining_Extent - Natural'Min (Size, Remaining_Extent);
            Remaining_Weight := Remaining_Weight - State.Weights (I);
         end;
      end loop;
      end;

      return Result;
   end Layout;

   function Pane_At
     (Layout : Pane_Layout;
      Row    : Positive;
      Col    : Positive) return Pane_Count
   is
   begin
      for I in 1 .. Layout.Count loop
         declare
            Rect : constant Pane_Rect := Layout.Rects (I);
         begin
            if Rect.Rows > 0
              and then Rect.Cols > 0
              and then Row >= Rect.Row
              and then Row < Rect.Row + Rect.Rows
              and then Col >= Rect.Col
              and then Col < Rect.Col + Rect.Cols
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
      if Hit = 0 then
         Status := Invalid_Index;
      else
         Activate (State, Positive (Hit), Status);
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
         if Status = Ok then
            Apply (State, Close_Pane, Status);
         end if;
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
      Left_Rect : Pane_Rect;
      Right_Rect : Pane_Rect;
      Combined : Natural;
      Requested_Left : Natural;
      Total_Weight : Natural;
      Left_Weight : Natural;
   begin
      if Divider >= State.Current_Count or else Layout.Count /= State.Current_Count then
         Status := Invalid_Index;
         return;
      end if;

      Left_Rect := Layout.Rects (Divider);
      Right_Rect := Layout.Rects (Divider + 1);
      if State.Layout_Axis = Horizontal then
         Combined := Left_Rect.Rows + Right_Rect.Rows;
         Requested_Left :=
           Natural'Min
             (Combined - 1,
              Natural'Max (1, Natural (Row) - Left_Rect.Row + 1));
      else
         Combined := Left_Rect.Cols + Right_Rect.Cols;
         Requested_Left :=
           Natural'Min
             (Combined - 1,
              Natural'Max (1, Natural (Col) - Left_Rect.Col + 1));
      end if;
      if Combined < 2 then
         Status := Invalid_Index;
         return;
      end if;

      Total_Weight := State.Weights (Divider) + State.Weights (Divider + 1);
      Left_Weight := Natural'Max (1, Total_Weight * Requested_Left / Combined);
      Left_Weight := Natural'Min (Total_Weight - 1, Left_Weight);
      State.Weights (Divider) := Left_Weight;
      State.Weights (Divider + 1) := Total_Weight - Left_Weight;
      Status := Ok;
   end Move_Divider;

   function Trim_Image (Value : Natural) return String
      renames Terminal.Common.Status.Trimmed_Natural;

   function Pane_Label (Index : Pane_Index) return String is
   begin
      return "Pane " & Trim_Image (Index);
   end Pane_Label;

   function Fitted_Label
     (Index : Pane_Index;
      Width : Natural) return String
   is
      Text : constant String := Pane_Label (Index);
   begin
      if Width = 0 then
         return "";
      elsif Text'Length <= Width then
         return Text;
      elsif Width <= 3 then
         return Text (Text'First .. Text'First + Width - 1);
      else
         return Text (Text'First .. Text'First + Width - 4) & "...";
      end if;
   end Fitted_Label;

   function Status_Label (State : Split_State) return String is
   begin
      if State.Current_Count = 0 then
         return "No live panes";
      elsif State.Current_Count = 1 then
         return "Single live pane";
      else
         return "Live split panes="
           & Trim_Image (State.Current_Count)
           & " active="
           & Trim_Image (State.Active_Index);
      end if;
   end Status_Label;

   function Title_Suffix (State : Split_State) return String is
   begin
      if State.Current_Count <= 1 then
         return "";
      else
         return
           " pane "
           & Trim_Image (State.Active_Index)
           & "/"
           & Trim_Image (State.Current_Count);
      end if;
   end Title_Suffix;
end Terminal.App.Splits;
