with Terminal.Core.Storage;
with Terminal.Core.Hyperlink_Store;
with Terminal.Core.Snapshot_Cell_Storage;

package body Terminal.Core.Snapshot_Access is
   procedure Release (S : in out Render_Snapshot) is
   begin
      Snapshot_Cell_Storage.Release_Links (S, S.Storage.Cells_Data);
      Snapshot_Cell_Storage.Release_Links (S, S.Storage.Batch_Cells);
      Storage.Release (S.Storage.Cells_Data);
      Storage.Release (S.Storage.Batch_Cells);
      Storage.Release (S.Storage.Dirty_Data);
      Storage.Release (S.Storage.Prepared_Links);
      Storage.Release (S.Storage.Scroll_Events);
      Hyperlink_Store.Release_All (S.Storage.Hyperlinks);
      S.Rows := 0;
      S.Cols := 0;
      S.Graphics_Stream := 0;
      S.Graphics_Transaction := 0;
      S.Alternate_Screen := False;
      S.Screen_Generation := 0;
      S.Scrollback_Offset := 0;
      S.Scrollback_Rows := 0;
      S.Graphics_Scroll_Current := 0;
      S.Graphics_Scroll_Oldest := 0;
      S.Graphics_Scroll_Count := 0;
      S.Storage.Image_Cells := 0;
      S.Storage.Blinking_Cells := 0;
      S.Storage.Dirty_Rows := 0;
      S.Storage.Wide_Violations := 0;
      S.Cursor := (others => <>);
      S.Graphics := (others => <>);
   end Release;

   function Cell_Count (S : Render_Snapshot) return Natural is
     (if S.Storage.Cells_Data = null
      then 0 else S.Storage.Cells_Data'Length);

   function Image_Cell_Count (S : Render_Snapshot) return Natural is
     (S.Storage.Image_Cells);

   function Blinking_Cell_Count (S : Render_Snapshot) return Natural is
     (S.Storage.Blinking_Cells);

   function Rows (S : Render_Snapshot) return Natural is (S.Rows);
   function Cols (S : Render_Snapshot) return Natural is (S.Cols);
   function Graphics_Stream
     (S : Render_Snapshot) return Graphics_Stream_ID is (S.Graphics_Stream);
   function Graphics_Transaction
     (S : Render_Snapshot) return Graphics_Transaction_Generation is
     (S.Graphics_Transaction);
   function Alternate_Screen (S : Render_Snapshot) return Boolean is
     (S.Alternate_Screen);
   function Screen_Generation
     (S : Render_Snapshot) return Graphics_Screen_Generation is
     (S.Screen_Generation);
   function Scrollback_Offset (S : Render_Snapshot) return Natural is
     (S.Scrollback_Offset);
   function Scrollback_Rows (S : Render_Snapshot) return Natural is
     (S.Scrollback_Rows);
   function Graphics_Scroll_Current
     (S : Render_Snapshot) return Graphics_Scroll_Sequence is
     (S.Graphics_Scroll_Current);
   function Graphics_Scroll_Oldest
     (S : Render_Snapshot) return Graphics_Scroll_Sequence is
     (S.Graphics_Scroll_Oldest);
   function Graphics_Scroll_Count (S : Render_Snapshot) return Natural is
     (S.Graphics_Scroll_Count);
   function Cursor (S : Render_Snapshot) return Cursor_State is (S.Cursor);
   function Graphics (S : Render_Snapshot) return Graphics_Event is
     (S.Graphics);

   function Cell_Index_Valid
     (S : Render_Snapshot; Index : Positive) return Boolean
   is
     (S.Storage.Cells_Data /= null
      and then S.Rows > 0
      and then S.Cols > 0
      and then S.Rows <= Natural'Last / S.Cols
      and then Index <= S.Rows * S.Cols
      and then Index in S.Storage.Cells_Data'Range);

   function Is_Wide_Violation
     (S : Render_Snapshot; Position : Positive) return Boolean
   is
      Col   : Positive;
      Value : Snapshot_Cell renames S.Storage.Cells_Data (Position);
   begin
      Col := ((Position - 1) mod S.Cols) + 1;
      if Value.Kind = Wide_Continuation then
         return Col = 1
           or else S.Storage.Cells_Data (Position - 1).Kind /= Character
           or else S.Storage.Cells_Data (Position - 1).Text.Width /= Width_Two;
      elsif Value.Kind = Character and then Value.Text.Width = Width_Two then
         return Col = S.Cols
           or else S.Storage.Cells_Data (Position + 1).Kind /= Wide_Continuation;
      else
         return False;
      end if;
   end Is_Wide_Violation;

   function Affected_Wide_Violations
     (S : Render_Snapshot; Position : Positive) return Natural
   is
      First : constant Positive :=
        (if Position = 1 then 1 else Position - 1);
      Last  : constant Positive :=
        (if Position = S.Storage.Cells_Data'Last
         then Position
         else Position + 1);
      Count : Natural := 0;
   begin
      for I in First .. Last loop
         if Is_Wide_Violation (S, I) then
            Count := Count + 1;
         end if;
      end loop;
      return Count;
   end Affected_Wide_Violations;

   function Is_Valid (S : Render_Snapshot) return Boolean is
      Expected_Cells : Natural;
   begin
      if S.Rows = 0
        or else S.Cols = 0
        or else S.Rows > Natural'Last / S.Cols
      then
         return False;
      end if;
      Expected_Cells := S.Rows * S.Cols;
      if S.Storage.Cells_Data = null
        or else S.Storage.Cells_Data'Length /= Expected_Cells
        or else S.Storage.Dirty_Data = null
        or else S.Storage.Dirty_Data'Length /= S.Rows
        or else S.Cursor.Row > S.Rows
        or else S.Cursor.Col > S.Cols
        or else S.Graphics.Preview_Length > S.Graphics.Payload_Length
        or else
          (S.Graphics_Scroll_Count > 0
           and then
             (S.Storage.Scroll_Events = null
              or else S.Storage.Scroll_Events'Length <
                S.Graphics_Scroll_Count))
      then
         return False;
      end if;
      if S.Storage.Image_Cells > Expected_Cells
        or else S.Storage.Blinking_Cells > Expected_Cells
        or else S.Storage.Dirty_Rows > S.Rows
        or else S.Storage.Wide_Violations > Expected_Cells
      then
         return False;
      end if;
      return S.Storage.Wide_Violations = 0;
   end Is_Valid;

   function Cell_At_Index
     (S : Render_Snapshot; Index : Positive) return Cell is
   begin
      if S.Storage.Cells_Data = null
        or else S.Rows = 0
        or else S.Cols = 0
        or else S.Rows > Natural'Last / S.Cols
        or else Index > S.Rows * S.Cols
        or else Index not in S.Storage.Cells_Data'Range
      then
         raise Constraint_Error with "snapshot cell index out of bounds";
      end if;
      declare
         Value : Snapshot_Cell renames S.Storage.Cells_Data (Index);
      begin
         return
           (Includes_Link => True,
            Kind  => Value.Kind,
            Text  => Value.Text,
            Style => Value.Style,
            Link  =>
              (if Value.Link = null
               then (others => <>)
               else Value.Link.Value),
            Image => Value.Image);
      end;
   end Cell_At_Index;

   function Cell_At
     (S   : Render_Snapshot;
      Row : Positive;
      Col : Positive) return Cell
   is
   begin
      if S.Storage.Cells_Data = null
        or else Row > S.Rows
        or else Col > S.Cols
        or else (Row - 1) > Natural'Last / S.Cols
        or else (Row - 1) * S.Cols > Natural'Last - Col
        or else (Row - 1) * S.Cols + Col not in
          S.Storage.Cells_Data'Range
      then
         raise Constraint_Error with "snapshot cell coordinates out of bounds";
      end if;
      return Cell_At_Index (S, (Row - 1) * S.Cols + Col);
   end Cell_At;

   function Cell_Content_At
     (S   : Render_Snapshot;
      Row : Positive;
      Col : Positive) return Cell_Content
   is
      Index : Positive;
   begin
      if S.Storage.Cells_Data = null
        or else Row > S.Rows
        or else Col > S.Cols
      then
         raise Constraint_Error with "snapshot cell coordinates out of bounds";
      end if;
      Index := (Row - 1) * S.Cols + Col;
      declare
         Value : Snapshot_Cell renames S.Storage.Cells_Data (Index);
      begin
         return
           (Includes_Link => False,
            Kind  => Value.Kind,
            Text  => Value.Text,
            Style => Value.Style,
            Image => Value.Image);
      end;
   end Cell_Content_At;

   function Cell_Link_Equals
     (S     : Render_Snapshot;
      Row   : Positive;
      Col   : Positive;
      Value : Hyperlink) return Boolean
   is
      Index : Positive;
      Link  : Stored_Hyperlink_Access;
   begin
      if S.Storage.Cells_Data = null
        or else Row > S.Rows
        or else Col > S.Cols
      then
         raise Constraint_Error with "snapshot cell coordinates out of bounds";
      end if;
      Index := (Row - 1) * S.Cols + Col;
      Link := S.Storage.Cells_Data (Index).Link;
      return
        (if Link = null
         then not Value.Active
         else Value.Active and then Same_Hyperlink (Link.Value, Value));
   end Cell_Link_Equals;

   function Cell_Kind_At
     (S   : Render_Snapshot;
      Row : Positive;
      Col : Positive) return Cell_Kind is
   begin
      if S.Storage.Cells_Data = null
        or else Row > S.Rows
        or else Col > S.Cols
      then
         raise Constraint_Error with "snapshot cell coordinates out of bounds";
      end if;
      return S.Storage.Cells_Data ((Row - 1) * S.Cols + Col).Kind;
   end Cell_Kind_At;

   function Cell_Text_At
     (S   : Render_Snapshot;
      Row : Positive;
      Col : Positive) return Text_Cluster is
   begin
      if S.Storage.Cells_Data = null
        or else Row > S.Rows
        or else Col > S.Cols
      then
         raise Constraint_Error with "snapshot cell coordinates out of bounds";
      end if;
      return S.Storage.Cells_Data ((Row - 1) * S.Cols + Col).Text;
   end Cell_Text_At;

   function Cell_Style_At_Index
     (S : Render_Snapshot; Index : Positive) return Cell_Style is
   begin
      if not Cell_Index_Valid (S, Index) then
         raise Constraint_Error with "snapshot cell index out of bounds";
      end if;
      return S.Storage.Cells_Data (Index).Style;
   end Cell_Style_At_Index;

   function Has_Dirty_Rows (S : Render_Snapshot) return Boolean is
     (S.Storage.Dirty_Rows > 0);

   function Dirty_Row
     (S : Render_Snapshot; Row : Positive) return Boolean is
   begin
      if S.Storage.Dirty_Data = null
        or else Row > S.Rows
        or else Row not in S.Storage.Dirty_Data'Range
      then
         raise Constraint_Error with "snapshot dirty row out of bounds";
      end if;
      return S.Storage.Dirty_Data (Row);
   end Dirty_Row;

   function Has_Graphics_Scroll_Events
     (S : Render_Snapshot) return Boolean is
     (S.Graphics_Scroll_Count > 0
      and then S.Storage.Scroll_Events /= null
      and then S.Storage.Scroll_Events'Length >= S.Graphics_Scroll_Count);

   function Graphics_Scroll_Event_At
     (S : Render_Snapshot; Index : Positive) return Graphics_Scroll_Event is
   begin
      if S.Storage.Scroll_Events = null
        or else Index > S.Graphics_Scroll_Count
        or else Index not in S.Storage.Scroll_Events'Range
      then
         raise Constraint_Error with
           "snapshot graphics scroll event index out of bounds";
      end if;
      return S.Storage.Scroll_Events (Index);
   end Graphics_Scroll_Event_At;

   procedure Set_Cell
     (S     : in out Render_Snapshot;
      Index : Positive;
      Value : Cell)
   is
   begin
      Set_Cell_Deferred (S, Index, Value);
   end Set_Cell;

   procedure Replace_All_Cells
     (S           : in out Render_Snapshot;
      Value_At    : not null access function
        (Index : Positive) return Cell)
   is
      Count : constant Natural := Cell_Count (S);
      Replacement : Snapshot_Cell_Array_Access := null;
      Image_Count : Natural := 0;
      Blinking_Count : Natural := 0;
      Wide_Count : Natural := 0;

   begin
      if Count = 0
        or else S.Rows > Natural'Last / S.Cols
      then
         raise Constraint_Error with "snapshot cell batch out of bounds";
      end if;
      Snapshot_Cell_Storage.Acquire_Batch
        (S, Positive (Count), Replacement);
      begin
         for Index in 1 .. Count loop
            declare
               Value : constant Cell := Value_At (Index);
            begin
               Replacement (Index) :=
                 (Kind  => Value.Kind,
                  Text  => Value.Text,
                  Style => Value.Style,
                  Link  => Hyperlink_Store.Intern_Snapshot
                    (S.Storage.Hyperlinks, Value.Link),
                  Image => Value.Image);
               if Value.Image.Is_Placeholder then
                  Image_Count := Image_Count + 1;
               end if;
               if Value.Style.Blink then
                  Blinking_Count := Blinking_Count + 1;
               end if;
            end;
         end loop;
         for Index in 1 .. Count loop
            declare
               Col : constant Positive := ((Index - 1) mod S.Cols) + 1;
               Value : Snapshot_Cell renames Replacement (Index);
            begin
               if (Value.Kind = Wide_Continuation
                   and then
                     (Col = 1
                      or else Replacement (Index - 1).Kind /= Character
                      or else Replacement (Index - 1).Text.Width /= Width_Two))
                 or else
                   (Value.Kind = Character
                    and then Value.Text.Width = Width_Two
                    and then
                      (Col = S.Cols
                       or else Replacement (Index + 1).Kind /=
                         Wide_Continuation))
               then
                  Wide_Count := Wide_Count + 1;
               end if;
            end;
         end loop;
      exception
         when others =>
            Snapshot_Cell_Storage.Abandon_Batch (S, Replacement);
            raise;
      end;

      Snapshot_Cell_Storage.Commit_Batch (S, Replacement);
      S.Storage.Image_Cells := Image_Count;
      S.Storage.Blinking_Cells := Blinking_Count;
      S.Storage.Wide_Violations := Wide_Count;
   end Replace_All_Cells;

   procedure Set_Cell_Deferred
     (S     : in out Render_Snapshot;
      Index : Positive;
      Value : Cell)
   is
   begin
      if not Cell_Index_Valid (S, Index) then
         raise Constraint_Error with "snapshot cell index out of bounds";
      end if;
      declare
         Compact : Snapshot_Cell :=
           (Kind  => Value.Kind,
            Text  => Value.Text,
            Style => Value.Style,
            Link  => Hyperlink_Store.Intern_Snapshot
              (S.Storage.Hyperlinks, Value.Link),
            Image => Value.Image);
      begin
         begin
            Set_Compact_Cell (S, Index, Compact);
            Compact.Link := null;
         exception
            when others =>
               Hyperlink_Store.Release_Snapshot
                 (S.Storage.Hyperlinks, Compact.Link);
               raise;
         end;
      end;
   end Set_Cell_Deferred;

   procedure Set_Compact_Cell
     (S     : in out Render_Snapshot;
      Index : Positive;
      Value : Snapshot_Cell)
   is
      Was_Image    : Boolean;
      Was_Blinking : Boolean;
      Before_Wide  : Natural;
      After_Wide   : Natural;
      New_Image_Count : Natural;
      New_Blinking_Count : Natural;
      New_Wide_Count : Natural;
      Previous : Snapshot_Cell;
   begin
      if not Cell_Index_Valid (S, Index) then
         raise Constraint_Error with "snapshot cell index out of bounds";
      end if;
      Was_Image := S.Storage.Cells_Data (Index).Image.Is_Placeholder;
      Was_Blinking := S.Storage.Cells_Data (Index).Style.Blink;
      Before_Wide := Affected_Wide_Violations (S, Index);
      New_Image_Count := S.Storage.Image_Cells;
      New_Blinking_Count := S.Storage.Blinking_Cells;
      if Was_Image /= Value.Image.Is_Placeholder then
         if Value.Image.Is_Placeholder then
            if New_Image_Count = Natural'Last then
               raise Constraint_Error with "snapshot image cell count overflow";
            end if;
            New_Image_Count := New_Image_Count + 1;
         elsif New_Image_Count = 0 then
            raise Program_Error with "snapshot image cell count underflow";
         else
            New_Image_Count := New_Image_Count - 1;
         end if;
      end if;
      if Was_Blinking /= Value.Style.Blink then
         if Value.Style.Blink then
            if New_Blinking_Count = Natural'Last then
               raise Constraint_Error with
                 "snapshot blinking cell count overflow";
            end if;
            New_Blinking_Count := New_Blinking_Count + 1;
         elsif New_Blinking_Count = 0 then
            raise Program_Error with "snapshot blinking cell count underflow";
         else
            New_Blinking_Count := New_Blinking_Count - 1;
         end if;
      end if;
      Previous := S.Storage.Cells_Data (Index);
      S.Storage.Cells_Data (Index) := Value;
      begin
         After_Wide := Affected_Wide_Violations (S, Index);
         if S.Storage.Wide_Violations < Before_Wide then
            raise Program_Error with "snapshot wide violation count underflow";
         elsif After_Wide >
           Natural'Last - (S.Storage.Wide_Violations - Before_Wide)
         then
            raise Constraint_Error with "snapshot wide violation count overflow";
         end if;
         New_Wide_Count :=
           S.Storage.Wide_Violations - Before_Wide + After_Wide;
      exception
         when others =>
            S.Storage.Cells_Data (Index) := Previous;
            raise;
      end;
      S.Storage.Image_Cells := New_Image_Count;
      S.Storage.Blinking_Cells := New_Blinking_Count;
      S.Storage.Wide_Violations := New_Wide_Count;
      Hyperlink_Store.Release_Snapshot
        (S.Storage.Hyperlinks, Previous.Link);
   end Set_Compact_Cell;

   procedure Set_Cell_Style
     (S     : in out Render_Snapshot;
      Index : Positive;
      Value : Cell_Style)
   is
      Was_Blinking : Boolean;
   begin
      if not Cell_Index_Valid (S, Index) then
         raise Constraint_Error with "snapshot cell index out of bounds";
      end if;
      Was_Blinking := S.Storage.Cells_Data (Index).Style.Blink;
      if Was_Blinking /= Value.Blink then
         if Value.Blink then
            if S.Storage.Blinking_Cells = Natural'Last then
               raise Constraint_Error with
                 "snapshot blinking cell count overflow";
            end if;
            S.Storage.Blinking_Cells := S.Storage.Blinking_Cells + 1;
         elsif S.Storage.Blinking_Cells = 0 then
            raise Program_Error with "snapshot blinking cell count underflow";
         else
            S.Storage.Blinking_Cells := S.Storage.Blinking_Cells - 1;
         end if;
      end if;
      S.Storage.Cells_Data (Index).Style := Value;
   end Set_Cell_Style;

   procedure Set_Dirty_Row
     (S     : in out Render_Snapshot;
      Row   : Positive;
      Value : Boolean) is
   begin
      if S.Storage.Dirty_Data = null
        or else Row > S.Rows
        or else Row not in S.Storage.Dirty_Data'Range
      then
         raise Constraint_Error with "snapshot dirty row out of bounds";
      end if;
      if S.Storage.Dirty_Data (Row) /= Value then
         if Value then
            if S.Storage.Dirty_Rows = Natural'Last then
               raise Constraint_Error with "snapshot dirty row count overflow";
            end if;
            S.Storage.Dirty_Rows := S.Storage.Dirty_Rows + 1;
         elsif S.Storage.Dirty_Rows = 0 then
            raise Program_Error with "snapshot dirty row count underflow";
         else
            S.Storage.Dirty_Rows := S.Storage.Dirty_Rows - 1;
         end if;
      end if;
      S.Storage.Dirty_Data (Row) := Value;
   end Set_Dirty_Row;
end Terminal.Core.Snapshot_Access;
