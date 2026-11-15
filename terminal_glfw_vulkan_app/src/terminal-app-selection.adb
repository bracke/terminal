with Terminal.Core.Snapshot_Editing;
with Terminal.Common;

package body Terminal.App.Selection is
   use type Terminal.Core.Cell_Kind;
   use type Terminal.Core.Cell_Width;
   use type Terminal.Common.Code_Point;

   function Clamp_Pos (Value, Limit : Positive) return Positive is
     (Positive'Max (1, Positive'Min (Value, Limit)));

   function Offset_To_Index
     (Offset : Float;
      Step   : Positive;
      Limit  : Positive) return Positive
   is
   begin
      if Offset /= Offset or else Offset <= 0.0 then
         return 1;
      elsif Offset >= Float (Step) * Float (Limit) then
         return Limit;
      else
         --  The comparison above bounds the quotient before the conversion,
         --  so even extreme finite cursor coordinates cannot overflow
         --  Integer while being clamped to the terminal edge.
         return Positive
           (Integer (Float'Floor (Offset / Float (Step))) + 1);
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
      Selection.Mode := Linear;
      Selection.Anchor := Position;
      Selection.Focus := Position;
   end Begin_Selection;

   procedure Begin_Rectangular_Selection
     (Selection : in out Selection_State;
      Position  : Cell_Position)
   is
   begin
      Selection.Active := True;
      Selection.Has_Range := True;
      Selection.Mode := Rectangular;
      Selection.Anchor := Position;
      Selection.Focus := Position;
   end Begin_Rectangular_Selection;

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
         Selection.Mode := Linear;
         Selection.Focus := Position;
      end if;
   end Extend_Selection;

   function Is_Wide_Continuation
     (Snapshot : Terminal.Core.Render_Snapshot;
      Row      : Positive;
      Col      : Positive) return Boolean;

   function Is_Wide_Head
     (Snapshot : Terminal.Core.Render_Snapshot;
      Row      : Positive;
      Col      : Positive) return Boolean;

   function Is_Token_Code_Point
     (Code : Terminal.Common.Code_Point) return Boolean
   is
      C : constant Natural := Natural (Code);
   begin
      return
        (C in Character'Pos ('A') .. Character'Pos ('Z'))
        or else (C in Character'Pos ('a') .. Character'Pos ('z'))
        or else (C in Character'Pos ('0') .. Character'Pos ('9'))
        or else C = Character'Pos ('_')
        or else C = Character'Pos ('-')
        or else C = Character'Pos ('.')
        or else C = Character'Pos ('/')
        or else C = Character'Pos (':')
        or else C = Character'Pos ('@')
        or else C = Character'Pos ('%')
        or else C = Character'Pos ('+')
        or else C = Character'Pos ('~')
        or else C = Character'Pos ('?')
        or else C = Character'Pos ('&')
        or else C = Character'Pos ('=')
        or else C = Character'Pos ('#')
        or else
          (C > 16#7F#
           and then C not in 16#00A0# .. 16#00BF#
           and then C not in 16#2000# .. 16#206F#
           and then C not in 16#2190# .. 16#27BF#
           and then C not in 16#1F000# .. 16#1FAFF#);
   end Is_Token_Code_Point;

   function Is_Token_Cell
     (Snapshot : Terminal.Core.Render_Snapshot;
      Row      : Positive;
      Col      : Positive) return Boolean
   is
      Cell : constant Terminal.Core.Cell_Content :=
        Terminal.Core.Cell_Content_At (Snapshot, Row, Col);
   begin
      return Cell.Kind = Terminal.Core.Character
        and then Is_Token_Code_Point (Cell.Text.Code_Point);
   end Is_Token_Cell;

   procedure Select_Word
     (Selection : in out Selection_State;
      Snapshot  : Terminal.Core.Render_Snapshot;
      Position  : Cell_Position)
   is
      Row   : Positive;
      Col   : Positive;
      First : Positive;
      Last  : Positive;
   begin
      if Snapshot.Rows = 0
        or else Snapshot.Cols = 0
        or else Terminal.Core.Cell_Count (Snapshot) = 0
      then
         Clear (Selection);
         return;
      end if;

      Row := Clamp_Pos (Position.Row, Positive (Snapshot.Rows));
      Col := Clamp_Pos (Position.Col, Positive (Snapshot.Cols));
      if Is_Wide_Continuation (Snapshot, Row, Col) then
         Col := Col - 1;
      end if;

      if not Is_Token_Cell (Snapshot, Row, Col) then
         Begin_Selection (Selection, (Row => Row, Col => Col));
         Selection.Active := False;
         return;
      end if;

      First := Col;
      loop
         exit when First = 1;
         declare
            Candidate : Positive := First - 1;
         begin
            if Is_Wide_Continuation (Snapshot, Row, Candidate) then
               exit when Candidate = 1;
               Candidate := Candidate - 1;
            end if;

            exit when not Is_Token_Cell (Snapshot, Row, Candidate);
            First := Candidate;
         end;
      end loop;

      Last := Col;
      loop
         exit when Last >= Positive (Snapshot.Cols);
         declare
            Candidate : Positive := Last + 1;
         begin
            if Is_Wide_Continuation (Snapshot, Row, Candidate) then
               exit when Candidate >= Positive (Snapshot.Cols);
               Candidate := Candidate + 1;
            end if;

            exit when not Is_Token_Cell (Snapshot, Row, Candidate);
            Last := Candidate;
         end;
      end loop;

      Selection.Active := False;
      Selection.Has_Range := True;
      Selection.Mode := Linear;
      Selection.Anchor := (Row => Row, Col => First);
      Selection.Focus := (Row => Row, Col => Last);
   end Select_Word;

   procedure Select_Line
     (Selection : in out Selection_State;
      Snapshot  : Terminal.Core.Render_Snapshot;
      Position  : Cell_Position)
   is
      Row : Positive;
   begin
      if Snapshot.Rows = 0
        or else Snapshot.Cols = 0
        or else Terminal.Core.Cell_Count (Snapshot) = 0
      then
         Clear (Selection);
         return;
      end if;

      Row := Clamp_Pos (Position.Row, Positive (Snapshot.Rows));
      Selection.Active := False;
      Selection.Has_Range := True;
      Selection.Mode := Linear;
      Selection.Anchor := (Row => Row, Col => 1);
      Selection.Focus := (Row => Row, Col => Positive (Snapshot.Cols));
   end Select_Line;

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
      Selection.Mode := Linear;
      Selection.Anchor := (Row => 1, Col => 1);
      Selection.Focus := (Row => 1, Col => 1);
   end Clear;

   function Is_Active (Selection : Selection_State) return Boolean is
     (Selection.Active);

   function Has_Selection (Selection : Selection_State) return Boolean is
     (Selection.Has_Range);

   function Snapshot (Selection : Selection_State) return Selection_Snapshot is
     ((Active    => Selection.Active,
       Has_Range => Selection.Has_Range,
       Mode      => Selection.Mode,
       Anchor    => Selection.Anchor,
       Focus     => Selection.Focus));

   function Status_Label (Selection : Selection_State) return String is
   begin
      if not Selection.Has_Range then
         return "No local selection";
      elsif Selection.Mode = Rectangular then
         return "Rectangular selection active";
      elsif Selection.Active then
         return "Linear selection active";
      else
         return "Linear selection ready";
      end if;
   end Status_Label;

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

   procedure Rectangular_Bounds
     (Selection : Selection_State;
      Start_Pos : out Cell_Position;
      End_Pos   : out Cell_Position)
   is
   begin
      Start_Pos :=
        (Row => Positive'Min (Selection.Anchor.Row, Selection.Focus.Row),
         Col => Positive'Min (Selection.Anchor.Col, Selection.Focus.Col));
      End_Pos :=
        (Row => Positive'Max (Selection.Anchor.Row, Selection.Focus.Row),
         Col => Positive'Max (Selection.Anchor.Col, Selection.Focus.Col));
   end Rectangular_Bounds;

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

      if Selection.Mode = Rectangular then
         Rectangular_Bounds (Selection, Start_Pos, End_Pos);
         return Row >= Start_Pos.Row
           and then Row <= End_Pos.Row
           and then Col >= Start_Pos.Col
           and then Col <= End_Pos.Col;
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
      Kind : constant Terminal.Core.Cell_Kind :=
        Terminal.Core.Cell_Kind_At (Snapshot, Row, Col);
      Text : constant Terminal.Core.Text_Cluster :=
        Terminal.Core.Cell_Text_At (Snapshot, Row, Col);
   begin
      return Kind = Terminal.Core.Character
        and then Text.Width = Terminal.Core.Width_Two
        and then Text.Code_Point /= 0
        and then Col < Positive (Snapshot.Cols)
        and then Terminal.Core.Cell_Kind_At (Snapshot, Row, Col + 1) =
          Terminal.Core.Wide_Continuation;
   end Is_Wide_Head;

   function Is_Wide_Continuation
     (Snapshot : Terminal.Core.Render_Snapshot;
      Row      : Positive;
      Col      : Positive) return Boolean
   is
   begin
      return Col > 1
        and then Terminal.Core.Cell_Kind_At (Snapshot, Row, Col) =
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
      Cell : constant Terminal.Core.Cell_Content :=
        Terminal.Core.Cell_Content_At (Snapshot, Row, Col);
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

   function UTF8_Length (Code : Terminal.Common.Code_Point) return Positive is
      Value : constant Natural := Natural (Code);
   begin
      if Value <= 16#7F# then
         return 1;
      elsif Value <= 16#7FF# then
         return 2;
      elsif Value <= 16#FFFF# then
         return 3;
      else
         return 4;
      end if;
   end UTF8_Length;

   function Cluster_UTF8_Length
     (Cluster : Terminal.Core.Text_Cluster) return Natural
   is
      Result : Natural := UTF8_Length (Cluster.Code_Point);
   begin
      for I in 1 .. Cluster.Attachment_Count loop
         Result := Result + UTF8_Length (Cluster.Attachments (I));
      end loop;
      return Result;
   end Cluster_UTF8_Length;

   procedure Add_Length (Total : in out Natural; Amount : Natural) is
   begin
      if Amount > Natural'Last - Total then
         raise Storage_Error with "selected text is too large";
      end if;
      Total := Total + Amount;
   end Add_Length;

   function Selected_Text
     (Snapshot  : Terminal.Core.Render_Snapshot;
      Selection : Selection_State) return String
   is
      Start_Pos : Cell_Position;
      End_Pos   : Cell_Position;
      Exact_Length : Natural := 0;

      procedure Traverse
        (Measure : Boolean;
         Result  : in out String;
         Last    : in out Natural)
      is
         Have_Previous_Slice : Boolean := False;

         procedure Emit_Cluster (Cluster : Terminal.Core.Text_Cluster) is
         begin
            if Measure then
               Add_Length (Exact_Length, Cluster_UTF8_Length (Cluster));
            else
               Append_Cluster (Result, Last, Cluster);
            end if;
         end Emit_Cluster;

         procedure Emit_Byte (Value : Natural) is
         begin
            if Measure then
               Add_Length (Exact_Length, 1);
            else
               Append_Byte (Result, Last, Value);
            end if;
         end Emit_Byte;
      begin
         for Row in Start_Pos.Row ..
           Positive'Min (End_Pos.Row, Positive (Snapshot.Rows))
         loop
            declare
               Raw_First_Col : constant Positive :=
                 (if Selection.Mode = Rectangular or else Row = Start_Pos.Row
                  then Start_Pos.Col
                  else 1);
               Raw_Last_Col  : constant Positive :=
                 (if Selection.Mode = Rectangular or else Row = End_Pos.Row
                  then End_Pos.Col
                  else Positive (Snapshot.Cols));
               Has_Slice : constant Boolean :=
                 Raw_First_Col <= Positive (Snapshot.Cols)
                 and then Raw_First_Col <= Raw_Last_Col;
               First_Col : constant Positive :=
                 Positive'Min (Raw_First_Col, Positive (Snapshot.Cols));
               Last_Col : constant Positive :=
                 Positive'Min (Raw_Last_Col, Positive (Snapshot.Cols));
               Row_Last  : Natural := 0;
            begin
               if Has_Slice then
                  if Have_Previous_Slice then
                     Emit_Byte (Character'Pos (ASCII.LF));
                  end if;
                  Have_Previous_Slice := True;
                  for Col in First_Col .. Last_Col loop
                     if Is_Text_For_Selection (Snapshot, Row, Col) then
                        Row_Last := Col;
                     end if;
                  end loop;
                  if Row_Last > 0 then
                     for Col in First_Col .. Row_Last loop
                        declare
                           Cell : constant Terminal.Core.Cell_Content :=
                             Terminal.Core.Cell_Content_At
                               (Snapshot, Row, Col);
                        begin
                           if Cell.Kind = Terminal.Core.Character
                             and then Cell.Text.Code_Point /= 0
                           then
                              Emit_Cluster (Cell.Text);
                           elsif Is_Wide_Continuation (Snapshot, Row, Col)
                             and then not Contains (Selection, Row, Col - 1)
                           then
                              Emit_Cluster
                                (Terminal.Core.Cell_Content_At
                                   (Snapshot, Row, Col - 1).Text);
                           elsif Cell.Kind = Terminal.Core.Empty then
                              Emit_Byte (Character'Pos (' '));
                           end if;
                        end;
                     end loop;
                  end if;
               end if;
            end;
         end loop;
      end Traverse;
   begin
      if not Selection.Has_Range
        or else Snapshot.Rows = 0
        or else Snapshot.Cols = 0
        or else Terminal.Core.Cell_Count (Snapshot) = 0
      then
         return "";
      end if;

      if Selection.Mode = Rectangular then
         Rectangular_Bounds (Selection, Start_Pos, End_Pos);
      else
         Bounds (Selection, Start_Pos, End_Pos);
      end if;
      if Start_Pos.Row > Positive (Snapshot.Rows) then
         return "";
      end if;

      declare
         Dummy : String (1 .. 0);
         Last  : Natural := 0;
      begin
         Traverse (Measure => True, Result => Dummy, Last => Last);
      end;

      if Exact_Length = 0 then
         return "";
      end if;

      declare
         Last : Natural := 0;
      begin
         return Result : String (1 .. Exact_Length) do
            Traverse (Measure => False, Result => Result, Last => Last);
            if Last /= Exact_Length then
               raise Program_Error with "selected text length mismatch";
            end if;
         end return;
      end;
   end Selected_Text;

   procedure Apply_To_Snapshot
     (Snapshot  : in out Terminal.Core.Render_Snapshot;
      Selection : Selection_State)
   is
      Start_Pos : Cell_Position;
      End_Pos   : Cell_Position;
      First_Row : Positive;
      Last_Row  : Positive;
   begin
      if not Selection.Has_Range
        or else Snapshot.Rows = 0
        or else Snapshot.Cols = 0
        or else Terminal.Core.Cell_Count (Snapshot) = 0
      then
         return;
      end if;

      if Selection.Mode = Rectangular then
         Rectangular_Bounds (Selection, Start_Pos, End_Pos);
      else
         Bounds (Selection, Start_Pos, End_Pos);
      end if;
      First_Row := Positive'Min (Positive (Snapshot.Rows), Start_Pos.Row);
      Last_Row := Positive'Min (Positive (Snapshot.Rows), End_Pos.Row);
      if First_Row > Last_Row or else Start_Pos.Row > Positive (Snapshot.Rows) then
         return;
      end if;

      for Row in First_Row .. Last_Row loop
         declare
            Raw_Selected_First : constant Positive :=
              (if Selection.Mode = Rectangular or else Row = Start_Pos.Row
               then Start_Pos.Col
               else 1);
            Raw_Selected_Last : constant Positive :=
              (if Selection.Mode = Rectangular or else Row = End_Pos.Row
               then End_Pos.Col
               else Positive (Snapshot.Cols));
            Has_Slice : constant Boolean :=
              Raw_Selected_First <= Positive (Snapshot.Cols)
              and then Raw_Selected_First <= Raw_Selected_Last;
            Selected_First : constant Positive :=
              Positive'Min
                (Positive (Snapshot.Cols), Raw_Selected_First);
            Selected_Last : constant Positive :=
              Positive'Min
                (Positive (Snapshot.Cols), Raw_Selected_Last);
            First_Col : constant Positive :=
              (if Selected_First > 1 then Selected_First - 1 else 1);
            Last_Col : constant Positive :=
              (if Selected_Last < Positive (Snapshot.Cols)
               then Selected_Last + 1
               else Positive (Snapshot.Cols));
         begin
            if Has_Slice then
               for Col in First_Col .. Last_Col loop
                  if Contains_With_Wide (Selection, Snapshot, Row, Col) then
                     declare
                        Index : constant Positive :=
                          (Row - 1) * Positive (Snapshot.Cols) + Col;
                        Value : Terminal.Core.Cell_Style :=
                          Terminal.Core.Cell_Style_At_Index (Snapshot, Index);
                     begin
                        Value.Inverse := not Value.Inverse;
                        Terminal.Core.Snapshot_Editing.Set_Cell_Style
                          (Snapshot, Index, Value);
                        Terminal.Core.Snapshot_Editing.Set_Dirty_Row
                          (Snapshot, Row, True);
                     end;
                  end if;
               end loop;
            end if;
         end;
      end loop;
   end Apply_To_Snapshot;
end Terminal.App.Selection;
