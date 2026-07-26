with Terminal.Common;

package body Terminal.App.Selection is
   use type Terminal.Core.Cell_Kind;
   use type Terminal.Core.Cell_Width;
   use type Terminal.Core.Cell_Array_Access;
   use type Terminal.Common.Code_Point;

   function Clamp_Pos (Value, Limit : Positive) return Positive is
     (Positive'Max (1, Positive'Min (Value, Limit)));

   function Offset_To_Index
     (Offset : Float;
      Step   : Positive;
      Limit  : Positive) return Positive
   is
      Local : constant Float := Float'Max (0.0, Offset);
      Index : constant Integer :=
        Integer (Float'Floor (Local / Float (Step))) + 1;
   begin
      if Index < 1 then
         return 1;
      elsif Index > Limit then
         return Limit;
      else
         return Positive (Index);
      end if;
   end Offset_To_Index;

   function Cell_From_Pixels
     (X           : Float;
      Y           : Float;
      Cell_Width  : Positive;
      Cell_Height : Positive;
      Margin      : Natural;
      Rows        : Positive;
      Cols        : Positive) return Cell_Position
   is
      Local_X : constant Float := X - Float (Margin);
      Local_Y : constant Float := Y - Float (Margin);
   begin
      return
        (Row => Offset_To_Index (Local_Y, Cell_Height, Rows),
         Col => Offset_To_Index (Local_X, Cell_Width, Cols));
   end Cell_From_Pixels;

   procedure Begin_Selection
     (Selection : in out Selection_State;
      Position  : Cell_Position)
   is
   begin
      Selection.Active := True;
      Selection.Has_Range := True;
      Selection.Anchor := Position;
      Selection.Focus := Position;
   end Begin_Selection;

   procedure Update_Selection
     (Selection : in out Selection_State;
      Position  : Cell_Position)
   is
   begin
      if Selection.Active then
         Selection.Focus := Position;
      end if;
   end Update_Selection;

   procedure Extend_Selection
     (Selection : in out Selection_State;
      Position  : Cell_Position)
   is
   begin
      if not Selection.Has_Range then
         Begin_Selection (Selection, Position);
      else
         Selection.Active := True;
         Selection.Focus := Position;
      end if;
   end Extend_Selection;

   procedure Finish_Selection
     (Selection : in out Selection_State;
      Position  : Cell_Position)
   is
   begin
      if Selection.Active then
         Selection.Focus := Position;
         Selection.Active := False;
      end if;
   end Finish_Selection;

   procedure Clear (Selection : in out Selection_State) is
   begin
      Selection.Active := False;
      Selection.Has_Range := False;
      Selection.Anchor := (Row => 1, Col => 1);
      Selection.Focus := (Row => 1, Col => 1);
   end Clear;

   function Is_Active (Selection : Selection_State) return Boolean is
     (Selection.Active);

   function Has_Selection (Selection : Selection_State) return Boolean is
     (Selection.Has_Range);

   function Before_Or_Equal (Left, Right : Cell_Position) return Boolean is
     (Left.Row < Right.Row
      or else (Left.Row = Right.Row and then Left.Col <= Right.Col));

   procedure Bounds
     (Selection : Selection_State;
      Start_Pos : out Cell_Position;
      End_Pos   : out Cell_Position)
   is
   begin
      if Before_Or_Equal (Selection.Anchor, Selection.Focus) then
         Start_Pos := Selection.Anchor;
         End_Pos := Selection.Focus;
      else
         Start_Pos := Selection.Focus;
         End_Pos := Selection.Anchor;
      end if;
   end Bounds;

   function Contains
     (Selection : Selection_State;
      Row       : Positive;
      Col       : Positive) return Boolean
   is
      Start_Pos : Cell_Position;
      End_Pos   : Cell_Position;
      Here      : constant Cell_Position := (Row => Row, Col => Col);
   begin
      if not Selection.Has_Range then
         return False;
      end if;

      Bounds (Selection, Start_Pos, End_Pos);
      return Before_Or_Equal (Start_Pos, Here)
        and then Before_Or_Equal (Here, End_Pos);
   end Contains;

   function Is_Wide_Head
     (Snapshot : Terminal.Core.Render_Snapshot;
      Row      : Positive;
      Col      : Positive) return Boolean
   is
      Cell : constant Terminal.Core.Cell :=
        Terminal.Core.Cell_At (Snapshot, Row, Col);
   begin
      return Cell.Kind = Terminal.Core.Character
        and then Cell.Text.Width = Terminal.Core.Width_Two
        and then Cell.Text.Code_Point /= 0
        and then Col < Positive (Snapshot.Cols)
        and then Terminal.Core.Cell_At (Snapshot, Row, Col + 1).Kind =
          Terminal.Core.Wide_Continuation;
   end Is_Wide_Head;

   function Is_Wide_Continuation
     (Snapshot : Terminal.Core.Render_Snapshot;
      Row      : Positive;
      Col      : Positive) return Boolean
   is
   begin
      return Col > 1
        and then Terminal.Core.Cell_At (Snapshot, Row, Col).Kind =
          Terminal.Core.Wide_Continuation
        and then Is_Wide_Head (Snapshot, Row, Col - 1);
   end Is_Wide_Continuation;

   function Contains_With_Wide
     (Selection : Selection_State;
      Snapshot  : Terminal.Core.Render_Snapshot;
      Row       : Positive;
      Col       : Positive) return Boolean
   is
   begin
      return Contains (Selection, Row, Col)
        or else
          (Is_Wide_Head (Snapshot, Row, Col)
           and then Contains (Selection, Row, Col + 1))
        or else
          (Is_Wide_Continuation (Snapshot, Row, Col)
           and then Contains (Selection, Row, Col - 1));
   end Contains_With_Wide;

   function Is_Text_For_Selection
     (Snapshot : Terminal.Core.Render_Snapshot;
      Row      : Positive;
      Col      : Positive) return Boolean
   is
      Cell : constant Terminal.Core.Cell :=
        Terminal.Core.Cell_At (Snapshot, Row, Col);
   begin
      return
        (Cell.Kind = Terminal.Core.Character and then Cell.Text.Code_Point /= 0)
        or else Is_Wide_Continuation (Snapshot, Row, Col);
   end Is_Text_For_Selection;

   procedure Append_Byte
     (Result : in out String;
      Last   : in out Natural;
      Value  : Natural)
   is
   begin
      Last := Last + 1;
      Result (Last) := Character'Val (Value);
   end Append_Byte;

   procedure Append_UTF8
     (Result : in out String;
      Last   : in out Natural;
      Code   : Terminal.Common.Code_Point)
   is
      C : constant Natural := Natural (Code);
   begin
      if C <= 16#7F# then
         Append_Byte (Result, Last, C);
      elsif C <= 16#7FF# then
         Append_Byte (Result, Last, 16#C0# + C / 64);
         Append_Byte (Result, Last, 16#80# + C mod 64);
      elsif C <= 16#FFFF# then
         Append_Byte (Result, Last, 16#E0# + C / 4096);
         Append_Byte (Result, Last, 16#80# + (C / 64) mod 64);
         Append_Byte (Result, Last, 16#80# + C mod 64);
      else
         Append_Byte (Result, Last, 16#F0# + C / 262_144);
         Append_Byte (Result, Last, 16#80# + (C / 4096) mod 64);
         Append_Byte (Result, Last, 16#80# + (C / 64) mod 64);
         Append_Byte (Result, Last, 16#80# + C mod 64);
      end if;
   end Append_UTF8;

   procedure Append_Cluster
     (Result  : in out String;
      Last    : in out Natural;
      Cluster : Terminal.Core.Text_Cluster)
   is
   begin
      Append_UTF8 (Result, Last, Cluster.Code_Point);
      for I in 1 .. Cluster.Attachment_Count loop
         Append_UTF8 (Result, Last, Cluster.Attachments (I));
      end loop;
   end Append_Cluster;

   function Selected_Text
     (Snapshot  : Terminal.Core.Render_Snapshot;
      Selection : Selection_State) return String
   is
      Start_Pos : Cell_Position;
      End_Pos   : Cell_Position;
      Max_Length : constant Natural :=
        Snapshot.Rows * Snapshot.Cols *
          (Terminal.Core.Max_Cluster_Attachments + 1) * 4 + Snapshot.Rows;
   begin
      if not Selection.Has_Range
        or else Snapshot.Rows = 0
        or else Snapshot.Cols = 0
        or else Snapshot.Cells = null
        or else Max_Length = 0
      then
         return "";
      end if;

      Bounds (Selection, Start_Pos, End_Pos);
      Start_Pos.Row := Clamp_Pos (Start_Pos.Row, Positive (Snapshot.Rows));
      Start_Pos.Col := Clamp_Pos (Start_Pos.Col, Positive (Snapshot.Cols));
      End_Pos.Row := Clamp_Pos (End_Pos.Row, Positive (Snapshot.Rows));
      End_Pos.Col := Clamp_Pos (End_Pos.Col, Positive (Snapshot.Cols));

      declare
         Result : String (1 .. Max_Length);
         Last   : Natural := 0;
      begin
         for Row in Start_Pos.Row .. End_Pos.Row loop
            declare
               First_Col : constant Positive :=
                 (if Row = Start_Pos.Row then Start_Pos.Col else 1);
               Last_Col  : constant Positive :=
                 (if Row = End_Pos.Row then End_Pos.Col
                  else Positive (Snapshot.Cols));
               Row_Last  : Natural := 0;
            begin
               for Col in First_Col .. Last_Col loop
                  declare
                     Cell : constant Terminal.Core.Cell :=
                       Terminal.Core.Cell_At (Snapshot, Row, Col);
                  begin
                     if Is_Text_For_Selection (Snapshot, Row, Col) then
                        Row_Last := Col;
                     end if;
                  end;
               end loop;

               if Row_Last > 0 then
                  for Col in First_Col .. Row_Last loop
                     declare
                        Cell : constant Terminal.Core.Cell :=
                          Terminal.Core.Cell_At (Snapshot, Row, Col);
                     begin
                        if Cell.Kind = Terminal.Core.Character
                          and then Cell.Text.Code_Point /= 0
                        then
                           Append_Cluster (Result, Last, Cell.Text);
                        elsif Is_Wide_Continuation (Snapshot, Row, Col)
                          and then not Contains (Selection, Row, Col - 1)
                        then
                           Append_Cluster
                             (Result,
                              Last,
                              Terminal.Core.Cell_At
                                (Snapshot, Row, Col - 1).Text);
                        elsif Cell.Kind = Terminal.Core.Empty then
                           Append_Byte (Result, Last, Character'Pos (' '));
                        end if;
                     end;
                  end loop;
               end if;

               if Row < End_Pos.Row then
                  Append_Byte (Result, Last, Character'Pos (ASCII.LF));
               end if;
            end;
         end loop;

         return Result (1 .. Last);
      end;
   end Selected_Text;

   procedure Apply_To_Snapshot
     (Snapshot  : in out Terminal.Core.Render_Snapshot;
      Selection : Selection_State)
   is
   begin
      if not Selection.Has_Range
        or else Snapshot.Rows = 0
        or else Snapshot.Cols = 0
        or else Snapshot.Cells = null
      then
         return;
      end if;

      for Row in 1 .. Positive (Snapshot.Rows) loop
         for Col in 1 .. Positive (Snapshot.Cols) loop
            if Contains_With_Wide (Selection, Snapshot, Row, Col) then
               Snapshot.Cells
                 ((Row - 1) * Positive (Snapshot.Cols) + Col).Style.Inverse :=
                   not Snapshot.Cells
                     ((Row - 1) * Positive (Snapshot.Cols) + Col).Style.Inverse;
            end if;
         end loop;
      end loop;
   end Apply_To_Snapshot;
end Terminal.App.Selection;
