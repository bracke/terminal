with Terminal.Core.Snapshot_Editing;
package body Terminal.App.Text_Blink is
   function Contains_Blinking_Text
     (Snapshot : Terminal.Core.Render_Snapshot) return Boolean
   is
   begin
      return Terminal.Core.Blinking_Cell_Count (Snapshot) > 0;
   end Contains_Blinking_Text;

   function Status_Label
     (Snapshot     : Terminal.Core.Render_Snapshot;
      Current_Tick : Natural) return String
   is
   begin
      if not Contains_Blinking_Text (Snapshot) then
         return "Text blink inactive";
      elsif Current_Tick mod 2 = 0 then
         return "Text blink visible";
      else
         return "Text blink hidden";
      end if;
   end Status_Label;

   procedure Apply
     (Snapshot     : in out Terminal.Core.Render_Snapshot;
      Current_Tick : Natural)
   is
   begin
      if Terminal.Core.Cell_Count (Snapshot) = 0
        or else Current_Tick mod 2 = 0
      then
         return;
      end if;

      for Index in 1 .. Terminal.Core.Cell_Count (Snapshot) loop
         if Terminal.Core.Cell_Style_At_Index (Snapshot, Index).Blink then
            declare
               Value : Terminal.Core.Cell_Style :=
                 Terminal.Core.Cell_Style_At_Index (Snapshot, Index);
            begin
               Value.Conceal := True;
               Terminal.Core.Snapshot_Editing.Set_Cell_Style (Snapshot, Index, Value);
               Terminal.Core.Snapshot_Editing.Set_Dirty_Row
                 (Snapshot,
                  (Index - 1) / Positive (Snapshot.Cols) + 1,
                  True);
            end;
         end if;
      end loop;
   end Apply;
end Terminal.App.Text_Blink;
