with Ada.Exceptions;
with Terminal.Core.Cleanup_Diagnostics;
with Terminal.Core.Hyperlink_Store;
with Terminal.Core.Snapshot_Access;

package body Terminal.Core.Snapshot_Testing is
   procedure Set_Presentation_Context
     (S                 : in out Render_Snapshot;
      Stream            : Graphics_Stream_ID;
      Transaction       : Graphics_Transaction_Generation;
      Alternate         : Boolean;
      Screen_Generation : Graphics_Screen_Generation) is
   begin
      S.Graphics_Stream := Stream;
      S.Graphics_Transaction := Transaction;
      S.Alternate_Screen := Alternate;
      S.Screen_Generation := Screen_Generation;
   end Set_Presentation_Context;

   function Cell_Replacement_Is_Atomic
     (S : in out Render_Snapshot) return Boolean
   is
      Previous : constant Snapshot_Cell := S.Storage.Cells_Data (1);
      Original_Images : constant Natural := S.Storage.Image_Cells;
      Original_Blinking : constant Natural := S.Storage.Blinking_Cells;
      Original_Wide : constant Natural := S.Storage.Wide_Violations;
      Replacement : Cell := Cell_At_Index (S, 1);
      Injected_Blinking : Natural;
      Rejected : Boolean := False;
      Preserved : Boolean;
   begin
      Replacement.Image.Is_Placeholder :=
        not Previous.Image.Is_Placeholder;
      Replacement.Style.Blink := not Previous.Style.Blink;
      Injected_Blinking :=
        (if Replacement.Style.Blink then Natural'Last else 0);
      S.Storage.Blinking_Cells := Injected_Blinking;
      begin
         Snapshot_Access.Set_Cell (S, 1, Replacement);
      exception
         when Constraint_Error | Program_Error =>
            Rejected := True;
      end;
      Preserved :=
        Rejected
        and then S.Storage.Cells_Data (1) = Previous
        and then S.Storage.Image_Cells = Original_Images
        and then S.Storage.Blinking_Cells = Injected_Blinking
        and then S.Storage.Wide_Violations = Original_Wide;

      S.Storage.Blinking_Cells := Original_Blinking;
      if Preserved then
         declare
            Last_Index : constant Positive := Positive (S.Cols);
            Previous_Last : constant Snapshot_Cell :=
              S.Storage.Cells_Data (Last_Index);
            Replacement_Last : constant Cell :=
              Cell_At_Index (S, Last_Index);
            Violating : Snapshot_Cell := Previous_Last;
            Wide_Rejected : Boolean := False;
         begin
            Violating.Kind := Character;
            Violating.Text.Width := Width_Two;
            S.Storage.Cells_Data (Last_Index) := Violating;
            S.Storage.Wide_Violations := 0;
            begin
               Snapshot_Access.Set_Cell
                 (S, Last_Index, Replacement_Last);
            exception
               when Constraint_Error | Program_Error =>
                  Wide_Rejected := True;
            end;
            Preserved :=
              Wide_Rejected
              and then S.Storage.Cells_Data (Last_Index) = Violating
              and then S.Storage.Image_Cells = Original_Images
              and then S.Storage.Blinking_Cells = Original_Blinking
              and then S.Storage.Wide_Violations = 0;
            S.Storage.Cells_Data (Last_Index) := Previous_Last;
         exception
            when others =>
               S.Storage.Cells_Data (Last_Index) := Previous_Last;
               S.Storage.Wide_Violations := Original_Wide;
               raise;
         end;
      end if;

      S.Storage.Cells_Data (1) := Previous;
      S.Storage.Image_Cells := Original_Images;
      S.Storage.Blinking_Cells := Original_Blinking;
      S.Storage.Wide_Violations := Original_Wide;
      return Preserved;
   exception
      when others =>
         S.Storage.Cells_Data (1) := Previous;
         S.Storage.Image_Cells := Original_Images;
         S.Storage.Blinking_Cells := Original_Blinking;
         S.Storage.Wide_Violations := Original_Wide;
         raise;
   end Cell_Replacement_Is_Atomic;

   function Batch_Replacement_Is_Atomic
     (S : in out Render_Snapshot) return Boolean
   is
      Original : constant Snapshot_Cell_Array := S.Storage.Cells_Data.all;
      Original_Images : constant Natural := S.Storage.Image_Cells;
      Original_Blinking : constant Natural := S.Storage.Blinking_Cells;
      Original_Wide : constant Natural := S.Storage.Wide_Violations;
      Rejected : Boolean := False;

      function Value_At (Index : Positive) return Cell is
      begin
         if Index = Positive'Min (3, Original'Last) then
            raise Storage_Error with "injected snapshot batch failure";
         end if;
         return Cell_At_Index (S, Index);
      end Value_At;
   begin
      begin
         Snapshot_Access.Replace_All_Cells
           (S, Value_At'Access);
      exception
         when Storage_Error =>
            Rejected := True;
      end;
      return Rejected
        and then S.Storage.Cells_Data.all = Original
        and then S.Storage.Image_Cells = Original_Images
        and then S.Storage.Blinking_Cells = Original_Blinking
        and then S.Storage.Wide_Violations = Original_Wide;
   end Batch_Replacement_Is_Atomic;

   function Prepared_Hyperlink_Scratch_Is_Clear
     (S : Render_Snapshot) return Boolean
   is
   begin
      if S.Storage.Prepared_Links = null then
         return False;
      end if;
      for Link of S.Storage.Prepared_Links.all loop
         if Link /= null then
            return False;
         end if;
      end loop;
      return True;
   end Prepared_Hyperlink_Scratch_Is_Clear;

   function Cleanup_Diagnostic_Is_Observable return Boolean is
      Diagnostic : Snapshot_Finalizer_Diagnostic;
   begin
      Reset_Snapshot_Finalizer_Diagnostics;
      begin
         raise Constraint_Error with "injected snapshot cleanup failure";
      exception
         when Error : others =>
            Cleanup_Diagnostics.Note_Snapshot_Finalizer_Failure (Error);
      end;
      Diagnostic := Snapshot_Finalizer_Diagnostics;
      Reset_Snapshot_Finalizer_Diagnostics;
      return
        Diagnostic.Count = 1
        and then Diagnostic.Exception_Length > 0
        and then Diagnostic.Exception_Name
          (1 .. Diagnostic.Exception_Length) =
            Ada.Exceptions.Exception_Name (Constraint_Error'Identity)
        and then Snapshot_Finalizer_Failure_Count = 0;
   end Cleanup_Diagnostic_Is_Observable;

   function Snapshot_Refresh_Is_Atomic
     (T          : Terminal'Class;
      S          : in out Render_Snapshot;
      Force_Full : Boolean;
      Successful_Interns : Natural) return Boolean
   is
      Original_Cells : constant Snapshot_Cell_Array :=
        S.Storage.Cells_Data.all;
      Original_Rows : constant Natural := S.Rows;
      Original_Cols : constant Natural := S.Cols;
      Original_Stream : constant Graphics_Stream_ID := S.Graphics_Stream;
      Original_Transaction : constant Graphics_Transaction_Generation :=
        S.Graphics_Transaction;
      Original_Alternate : constant Boolean := S.Alternate_Screen;
      Original_Generation : constant Graphics_Screen_Generation :=
        S.Screen_Generation;
      Original_Offset : constant Natural := S.Scrollback_Offset;
      Original_Scrollback_Rows : constant Natural := S.Scrollback_Rows;
      Original_Image_Cells : constant Natural := S.Storage.Image_Cells;
      Original_Blinking_Cells : constant Natural := S.Storage.Blinking_Cells;
      Original_Dirty_Rows : constant Natural := S.Storage.Dirty_Rows;
      Original_Wide : constant Natural := S.Storage.Wide_Violations;
      Remaining_Interns : Natural := Successful_Interns;
      Rejected : Boolean := False;

      function Intern_With_Failure
        (State : in out Hyperlink_Runtime_State;
         Value : Hyperlink) return Stored_Hyperlink_Access
      is
      begin
         if Remaining_Interns = 0 then
            raise Storage_Error with "injected snapshot hyperlink failure";
         end if;
         Remaining_Interns := Remaining_Interns - 1;
         return Hyperlink_Store.Intern_Snapshot (State, Value);
      end Intern_With_Failure;
   begin
      if Force_Full then
         S.Scrollback_Offset := 1;
      end if;
      begin
         Build_Snapshot (T, S, Intern_With_Failure'Access);
      exception
         when Storage_Error =>
            Rejected := True;
      end;
      if Force_Full then
         S.Scrollback_Offset := Original_Offset;
      end if;
      return Rejected
        and then S.Rows = Original_Rows
        and then S.Cols = Original_Cols
        and then S.Graphics_Stream = Original_Stream
        and then S.Graphics_Transaction = Original_Transaction
        and then S.Alternate_Screen = Original_Alternate
        and then S.Screen_Generation = Original_Generation
        and then S.Scrollback_Offset = Original_Offset
        and then S.Scrollback_Rows = Original_Scrollback_Rows
        and then S.Storage.Cells_Data.all = Original_Cells
        and then S.Storage.Image_Cells = Original_Image_Cells
        and then S.Storage.Blinking_Cells = Original_Blinking_Cells
        and then S.Storage.Dirty_Rows = Original_Dirty_Rows
        and then S.Storage.Wide_Violations = Original_Wide;
   exception
      when others =>
         S.Scrollback_Offset := Original_Offset;
         raise;
   end Snapshot_Refresh_Is_Atomic;
end Terminal.Core.Snapshot_Testing;
