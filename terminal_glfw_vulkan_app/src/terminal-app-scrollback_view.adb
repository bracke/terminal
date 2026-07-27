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
         Shape   => Live.Cursor.Shape,
         Blinking => Live.Cursor.Blinking);
      Terminal.Core.Release (Live);
      return Result;
   exception
      when Storage_Error =>
         Terminal.Core.Release (Live);
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
