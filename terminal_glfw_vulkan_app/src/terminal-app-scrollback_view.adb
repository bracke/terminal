with Terminal.Core;

package body Terminal.App.Scrollback_View is
   function Natural_Image (Value : Natural) return String is
      Image : constant String := Natural'Image (Value);
   begin
      return Image (Image'First + 1 .. Image'Last);
   end Natural_Image;

   function Bounded (Text : String) return String is
      Result : String (1 .. Max_Status_Label_Length);
      Last   : Natural := 0;
   begin
      for Ch of Text loop
         exit when Last = Result'Last;
         Last := Last + 1;
         Result (Last) := Ch;
      end loop;
      return Result (1 .. Last);
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
   begin
      Terminal.Core.Snapshot (T, Result);
      if Effective_Offset = 0 then
         return;
      end if;

      Result.Scrollback_Offset := Effective_Offset;
      Start_Row := Scroll_Rows - Effective_Offset + 1;
      Result.Image_Cell_Count := 0;

      --  Live rows move toward larger destination indices.  Walk backwards so
      --  the reusable snapshot can be transformed in place without replacing
      --  a live source row before it is copied.
      for Row in reverse 1 .. Result.Rows loop
         declare
            Source_Row : constant Natural := Start_Row + Row - 1;
         begin
            for Col in 1 .. Result.Cols loop
               declare
                  Cell : constant Terminal.Core.Cell :=
                    (if Source_Row <= Scroll_Rows
                     then Terminal.Core.Scrollback_Cell_At
                       (T, Source_Row, Col)
                     else Terminal.Core.Cell_At
                       (Result, Source_Row - Scroll_Rows, Col));
               begin
                  Result.Cells ((Row - 1) * Result.Cols + Col) := Cell;
                  if Cell.Image.Is_Placeholder then
                     Result.Image_Cell_Count := Result.Image_Cell_Count + 1;
                  end if;
               end;
            end loop;
            Result.Dirty (Row) := True;
         end;
      end loop;

      Result.Cursor :=
        (Row     => Result.Cursor.Row,
         Col     => Result.Cursor.Col,
         Visible => False,
         Shape   => Result.Cursor.Shape,
         Blinking => Result.Cursor.Blinking);
   end Snapshot;

   function Snapshot
     (T      : Terminal.Core.Terminal;
      Offset : Natural) return Terminal.Core.Render_Snapshot
   is
      Result : Terminal.Core.Render_Snapshot;
   begin
      Snapshot (T, Offset, Result);
      return Result;
   exception
      when Storage_Error =>
         Terminal.Core.Release (Result);
         return Terminal.Core.Snapshot (T);
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
end Terminal.App.Scrollback_View;
