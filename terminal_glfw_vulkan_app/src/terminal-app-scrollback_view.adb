with Terminal.Core;

package body Terminal.App.Scrollback_View is
   function Max_Offset (T : Terminal.Core.Terminal) return Natural is
   begin
      return Terminal.Core.Scrollback_Row_Count (T);
   end Max_Offset;

   function Clamp_Offset
     (T      : Terminal.Core.Terminal;
      Offset : Natural) return Natural
   is
   begin
      return Natural'Min (Offset, Max_Offset (T));
   end Clamp_Offset;

   function Snapshot
     (T      : Terminal.Core.Terminal;
      Offset : Natural) return Terminal.Core.Render_Snapshot
   is
      Live : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      Effective_Offset : constant Natural :=
        Natural'Min (Offset, Terminal.Core.Scrollback_Row_Count (T));
      Scroll_Rows : constant Natural := Terminal.Core.Scrollback_Row_Count (T);
      Start_Row : Natural;
      Result : Terminal.Core.Render_Snapshot;
   begin
      if Effective_Offset = 0 then
         return Live;
      end if;

      Result.Rows := Live.Rows;
      Result.Cols := Live.Cols;
      Result.Cells := new Terminal.Core.Cell_Array (1 .. Live.Rows * Live.Cols);
      Result.Dirty := new Terminal.Core.Dirty_Row_Array (1 .. Live.Rows);
      Start_Row := Scroll_Rows - Effective_Offset + 1;

      for Row in 1 .. Live.Rows loop
         declare
            Source_Row : constant Natural := Start_Row + Row - 1;
         begin
            for Col in 1 .. Live.Cols loop
               if Source_Row <= Scroll_Rows then
                  Result.Cells ((Row - 1) * Live.Cols + Col) :=
                    Terminal.Core.Scrollback_Cell_At (T, Source_Row, Col);
               else
                  Result.Cells ((Row - 1) * Live.Cols + Col) :=
                    Terminal.Core.Cell_At
                      (Live, Source_Row - Scroll_Rows, Col);
               end if;
            end loop;
            Result.Dirty (Row) := True;
         end;
      end loop;

      Result.Cursor :=
        (Row     => Live.Cursor.Row,
         Col     => Live.Cursor.Col,
         Visible => False,
         Shape   => Live.Cursor.Shape);
      Terminal.Core.Release (Live);
      return Result;
   exception
      when Storage_Error =>
         Terminal.Core.Release (Live);
         Terminal.Core.Release (Result);
         return Terminal.Core.Snapshot (T);
   end Snapshot;
end Terminal.App.Scrollback_View;
