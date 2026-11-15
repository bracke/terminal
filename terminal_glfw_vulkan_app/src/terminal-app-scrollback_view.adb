with Terminal.Core.Snapshot_Editing;
with Terminal.Core;
with Terminal.Common.Status;
with Terminal.App.Status_Labels;

package body Terminal.App.Scrollback_View is
   function Natural_Image (Value : Natural) return String
      renames Terminal.Common.Status.Trimmed_Natural;

   function Bounded (Text : String) return String is
   begin
      return Terminal.App.Status_Labels.Bounded
        (Text, Max_Status_Label_Length);
   end Bounded;

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

   procedure Snapshot
     (T      : Terminal.Core.Terminal;
      Offset : Natural;
      Result : in out Terminal.Core.Render_Snapshot)
   is
      Effective_Offset : constant Natural :=
        Natural'Min (Offset, Terminal.Core.Scrollback_Row_Count (T));
      Scroll_Rows : constant Natural := Terminal.Core.Scrollback_Row_Count (T);
      Start_Row : Natural;

      function Cell_At_Destination
        (Index : Positive) return Terminal.Core.Cell
      is
         Row : constant Positive := (Index - 1) / Result.Cols + 1;
         Col : constant Positive := (Index - 1) mod Result.Cols + 1;
         Source_Row : constant Natural := Start_Row + Row - 1;
      begin
         return
           (if Source_Row <= Scroll_Rows
            then Terminal.Core.Scrollback_Cell_At (T, Source_Row, Col)
            else Terminal.Core.Cell_At
              (Result, Source_Row - Scroll_Rows, Col));
      end Cell_At_Destination;
   begin
      Terminal.Core.Snapshot (T, Result);
      if Effective_Offset = 0 then
         return;
      end if;

      Start_Row := Scroll_Rows - Effective_Offset + 1;
      --  Prepare the complete composed view before swapping it into the
      --  snapshot, so a failed cell or hyperlink allocation changes nothing.
      Terminal.Core.Snapshot_Editing.Replace_All_Cells
        (Result,
         Cell_At_Destination'Access);
      Terminal.Core.Snapshot_Editing.Set_Scrollback_Offset
        (Result, Effective_Offset);
      for Row in 1 .. Result.Rows loop
         Terminal.Core.Snapshot_Editing.Set_Dirty_Row (Result, Row, True);
      end loop;

      Terminal.Core.Snapshot_Editing.Set_Cursor
        (Result,
         (Row     => Result.Cursor.Row,
          Col     => Result.Cursor.Col,
          Visible => False,
          Shape   => Result.Cursor.Shape,
          Blinking => Result.Cursor.Blinking));
   end Snapshot;

   function Snapshot
     (T      : Terminal.Core.Terminal;
      Offset : Natural) return Terminal.Core.Render_Snapshot
   is
   begin
      return Result : Terminal.Core.Render_Snapshot do
         begin
            Snapshot (T, Offset, Result);
         exception
            when Storage_Error =>
               Terminal.Core.Release (Result);
               Terminal.Core.Snapshot (T, Result);
         end;
      end return;
   end Snapshot;

   function Status_Label
     (T      : Terminal.Core.Terminal;
      Offset : Natural) return String
   is
      Max : constant Natural := Max_Offset (T);
      Effective : constant Natural := Natural'Min (Offset, Max);
   begin
      if Effective = 0 then
         return "Scrollback live";
      elsif Effective = Offset then
         return Bounded
           ("Scrollback "
            & Natural_Image (Effective)
            & "/"
            & Natural_Image (Max));
      else
         return Bounded
           ("Scrollback "
            & Natural_Image (Effective)
            & "/"
            & Natural_Image (Max)
            & " (clamped)");
      end if;
   end Status_Label;

   function Mark_Offset
     (T    : Terminal.Core.Terminal;
      Mark : Terminal.Core.Shell_Mark) return Natural
   is
      Produced : constant Natural := Terminal.Core.History_Rows_Produced (T);
   begin
      if Mark.History_Row > Produced then
         return 0;
      end if;
      return Clamp_Offset (T, Produced - Mark.History_Row + 1);
   end Mark_Offset;

   function Previous_Mark_Offset
     (T      : Terminal.Core.Terminal;
      Offset : Natural) return Natural
   is
      Count : constant Natural := Terminal.Core.Shell_Mark_Count (T);
      Candidate : Natural;
   begin
      for I in reverse 1 .. Count loop
         Candidate := Mark_Offset (T, Terminal.Core.Shell_Mark_At (T, I));
         if Candidate > Offset then
            return Candidate;
         end if;
      end loop;
      return Offset;
   end Previous_Mark_Offset;

   function Next_Mark_Offset
     (T      : Terminal.Core.Terminal;
      Offset : Natural) return Natural
   is
      Count : constant Natural := Terminal.Core.Shell_Mark_Count (T);
      Candidate : Natural;
   begin
      for I in 1 .. Count loop
         Candidate := Mark_Offset (T, Terminal.Core.Shell_Mark_At (T, I));
         if Candidate < Offset then
            return Candidate;
         end if;
      end loop;
      return Offset;
   end Next_Mark_Offset;
end Terminal.App.Scrollback_View;
