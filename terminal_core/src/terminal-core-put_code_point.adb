separate (Terminal.Core)
procedure Put_Code_Point (T : in out Terminal; CP : Common.Code_Point) is
   Cells : constant Cell_Array_Access := Active_Cells (T);
   W     : constant Cell_Width :=
     (if Is_Zero_Width (CP) then Width_Zero
      elsif Is_Wide (CP) then Width_Two
      else Width_One);

   function Previous_Cell_Index return Natural is
      Row : constant Positive := T.Cursor_Row;
      Col : Natural;
   begin
      if T.Pending_Wrap then
         Col := T.Cursor_Col;
      elsif T.Cursor_Col > 1 then
         Col := T.Cursor_Col - 1;
      else
         return 0;
      end if;

      if Cells (Index (T, Row, Positive (Col))).Kind = Wide_Continuation
        and then Col > 1
      then
         Col := Col - 1;
      end if;

      return Index (T, Row, Positive (Col));
   end Previous_Cell_Index;

   function Attach_To_Previous_Cell
     (Attached_CP : Common.Code_Point) return Boolean
   is
      Cell_Index : constant Natural := Previous_Cell_Index;

      function Should_Promote_To_Emoji_Width return Boolean is
      begin
         return
           (Attached_CP = 16#FE0F#
            and then Is_Emoji_Variation_Base
              (Cells (Cell_Index).Text.Code_Point))
           or else
             (Attached_CP = 16#20E3#
              and then Is_Keycap_Base
                (Cells (Cell_Index).Text.Code_Point));
      end Should_Promote_To_Emoji_Width;

      procedure Promote_Emoji_Width is
         Col : constant Positive :=
           Positive (((Cell_Index - 1) mod T.Cols) + 1);
         Next_Col : constant Positive := Col + 1;
      begin
         if Col = T.Cols
           or else Cells (Cell_Index).Text.Width /= Width_One
           or else not Should_Promote_To_Emoji_Width
         then
            return;
         end if;

         Clear_Wide_Overlap (T, T.Cursor_Row, Next_Col, Width_One);
         Cells (Cell_Index).Text.Width := Width_Two;
         Cells (Index (T, T.Cursor_Row, Next_Col)) :=
           (Kind  => Wide_Continuation,
            Text  => (Code_Point => 0,
                      Width      => Width_Zero,
                      others     => <>),
            Style => Cells (Cell_Index).Style,
            Link  => Cells (Cell_Index).Link,
            Image => <>);

         if T.Cursor_Col = Next_Col then
            if Next_Col = T.Cols then
               T.Pending_Wrap := True;
            else
               T.Cursor_Col := Next_Col + 1;
               T.Pending_Wrap := False;
            end if;
         end if;
      end Promote_Emoji_Width;
   begin
      if Cell_Index = 0 then
         return False;
      end if;

      if Cells (Cell_Index).Kind /= Character
        or else Cells (Cell_Index).Text.Code_Point = 0
      then
         return False;
      end if;

      if Cells (Cell_Index).Text.Attachment_Count <
        Max_Cluster_Attachments
      then
         Cells (Cell_Index).Text.Attachment_Count :=
           Cells (Cell_Index).Text.Attachment_Count + 1;
         Cells (Cell_Index).Text.Attachments
           (Cells (Cell_Index).Text.Attachment_Count) := Attached_CP;
         Decode_Image_Cell (T, Positive (Cell_Index));
         Promote_Emoji_Width;
         Mark_Dirty (T, T.Cursor_Row);
         return True;
      else
         T.Diag.Text_Cluster_Overflow := T.Diag.Text_Cluster_Overflow + 1;
         return False;
      end if;
   end Attach_To_Previous_Cell;

   function Previous_Cluster_Accepts_Spacing
     (Spacing_CP : Common.Code_Point) return Boolean
   is
      Cell_Index : constant Natural := Previous_Cell_Index;
      Count      : Cluster_Attachment_Count;
   begin
      if Cell_Index = 0
        or else Cells (Cell_Index).Kind /= Character
      then
         return False;
      end if;

      Count := Cells (Cell_Index).Text.Attachment_Count;
      return
        (Count > 0
         and then Cells (Cell_Index).Text.Attachments (Count) = 16#200D#)
        or else
          (Count = 0
           and then Is_Regional_Indicator
             (Cells (Cell_Index).Text.Code_Point)
           and then Is_Regional_Indicator (Spacing_CP))
        or else
          (Is_Emoji_Modifier (Spacing_CP)
           and then Cells (Cell_Index).Text.Width = Width_Two
           and then Is_Wide (Cells (Cell_Index).Text.Code_Point)
           and then not Is_Regional_Indicator
             (Cells (Cell_Index).Text.Code_Point));
   end Previous_Cluster_Accepts_Spacing;
begin
   if Cells = null then
      return;
   elsif W = Width_Zero then
      if not Attach_To_Previous_Cell (CP) then
         null;
      end if;
      return;
   elsif Previous_Cluster_Accepts_Spacing (CP) then
      if not Attach_To_Previous_Cell (CP) then
         null;
      end if;
      return;
   end if;

   if T.Pending_Wrap then
      T.Cursor_Col := 1;
      New_Line (T);
   end if;

   if W = Width_Two and then T.Cursor_Col = T.Cols then
      T.Cursor_Col := 1;
      New_Line (T);
   end if;

   if T.Current_Modes.Insert_Mode then
      Shift_Row_Right
        (T,
         T.Cursor_Row,
         T.Cursor_Col,
         (if W = Width_Two then 2 else 1));
   else
      Clear_Wide_Overlap (T, T.Cursor_Row, T.Cursor_Col, W);
   end if;

   Cells (Index (T, T.Cursor_Row, T.Cursor_Col)) :=
     (Kind  => Character,
      Text  => (Code_Point => CP, Width => W, others => <>),
      Style => T.Current_Style,
      Link  => T.Current_Link,
      Image => <>);
   Decode_Image_Cell (T, Index (T, T.Cursor_Row, T.Cursor_Col));
   T.Last_Printable := CP;
   T.Has_Last_Printable := True;
   Mark_Dirty (T, T.Cursor_Row);

   if W = Width_Two then
      if T.Cursor_Col < T.Cols then
         Cells (Index (T, T.Cursor_Row, T.Cursor_Col + 1)) :=
           (Kind => Wide_Continuation,
            Text => (Code_Point => 0, Width => Width_Zero, others => <>),
            Style => T.Current_Style,
            Link  => T.Current_Link,
            Image => <>);
      end if;
      if T.Cursor_Col + 1 >= T.Cols then
         T.Cursor_Col := T.Cols;
         T.Pending_Wrap := T.Current_Modes.Autowrap;
      else
         T.Cursor_Col := T.Cursor_Col + 2;
      end if;
   elsif T.Cursor_Col = T.Cols then
      T.Pending_Wrap := T.Current_Modes.Autowrap;
   else
      T.Cursor_Col := T.Cursor_Col + 1;
   end if;
end Put_Code_Point;
