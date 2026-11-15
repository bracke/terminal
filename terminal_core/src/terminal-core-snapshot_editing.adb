with Terminal.Core.Snapshot_Access;

package body Terminal.Core.Snapshot_Editing is
   procedure Set_Cursor
     (S : in out Render_Snapshot; Value : Cursor_State) is
   begin
      if S.Rows = 0
        or else S.Cols = 0
        or else Value.Row = 0
        or else Value.Col = 0
        or else Value.Row > S.Rows
        or else Value.Col > S.Cols
      then
         raise Constraint_Error with "snapshot cursor outside grid";
      end if;
      S.Cursor := Value;
   end Set_Cursor;
   procedure Set_Graphics
     (S : in out Render_Snapshot; Value : Graphics_Event) is
   begin
      if Value.Preview_Length > Value.Payload_Length then
         raise Constraint_Error with "snapshot graphics preview exceeds payload";
      end if;
      S.Graphics := Value;
   end Set_Graphics;
   procedure Set_Scrollback_Offset
     (S : in out Render_Snapshot; Value : Natural) is
   begin
      if Value > S.Scrollback_Rows then
         raise Constraint_Error with "snapshot scrollback offset out of bounds";
      end if;
      S.Scrollback_Offset := Value;
   end Set_Scrollback_Offset;
   procedure Set_Cell
     (S : in out Render_Snapshot; Index : Positive; Value : Cell)
      renames Snapshot_Access.Set_Cell;
   procedure Replace_All_Cells
     (S           : in out Render_Snapshot;
      Value_At    : not null access function
        (Index : Positive) return Cell)
      renames Snapshot_Access.Replace_All_Cells;
   procedure Set_Cell_Style
     (S : in out Render_Snapshot; Index : Positive; Value : Cell_Style)
      renames Snapshot_Access.Set_Cell_Style;
   procedure Set_Dirty_Row
     (S : in out Render_Snapshot; Row : Positive; Value : Boolean)
      renames Snapshot_Access.Set_Dirty_Row;
end Terminal.Core.Snapshot_Editing;
