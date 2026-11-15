with Terminal.Common.Status;

package body Terminal.App.Shell_Blocks is
   use type Terminal.Common.Code_Point;
   use type Terminal.Core.Cell_Kind;
   function Latest (T : Terminal.Core.Terminal) return Terminal.Core.Shell_Command_Block is
      Count : constant Natural := Terminal.Core.Shell_Command_Block_Count (T);
   begin
      if Count = 0 then
         return (others => <>);
      end if;
      return Terminal.Core.Shell_Command_Block_At (T, Count);
   end Latest;

   function Command_Text
     (T     : Terminal.Core.Terminal;
      Block : Terminal.Core.Shell_Command_Block) return String
   is
      Buffer : String (1 .. Max_Command_Length);
      Length : Natural := 0;
      Cols : constant Positive := Terminal.Core.Terminal_Column_Count (T);
      Last_Row : constant Natural :=
        (if Block.Has_Output then Block.Output_Row
         elsif Block.Complete then Block.Completion_Row
         else Block.Input_Row);

      procedure Append_Byte (Value : Natural) is
      begin
         if Length < Buffer'Last then
            Length := Length + 1;
            Buffer (Length) := Character'Val (Value);
         end if;
      end Append_Byte;

      procedure Append_Code_Point (Value : Terminal.Common.Code_Point) is
         V : constant Natural := Natural (Value);
      begin
         if V <= 16#7F# then
            Append_Byte (V);
         elsif V <= 16#7FF# then
            Append_Byte (16#C0# + V / 64);
            Append_Byte (16#80# + V mod 64);
         elsif V <= 16#FFFF# then
            Append_Byte (16#E0# + V / 4_096);
            Append_Byte (16#80# + (V / 64) mod 64);
            Append_Byte (16#80# + V mod 64);
         else
            Append_Byte (16#F0# + V / 262_144);
            Append_Byte (16#80# + (V / 4_096) mod 64);
            Append_Byte (16#80# + (V / 64) mod 64);
            Append_Byte (16#80# + V mod 64);
         end if;
      end Append_Code_Point;
   begin
      if not Block.Has_Input or else Last_Row < Block.Input_Row then
         return "";
      end if;
      for Row in Block.Input_Row .. Last_Row loop
         exit when not Terminal.Core.Absolute_Row_Available (T, Row);
         declare
            First_Col : constant Positive :=
              (if Row = Block.Input_Row then Block.Input_Col else 1);
            End_Col : Natural := Cols;
            Row_Length : constant Natural := Length;
         begin
            if Row = Last_Row then
               End_Col :=
                 (if Block.Has_Output then Block.Output_Col - 1
                  elsif Block.Complete then Block.Completion_Col - 1
                  else Cols);
            end if;
            if End_Col >= First_Col then
               for Col in First_Col .. End_Col loop
                  declare
                     Cell : constant Terminal.Core.Cell :=
                       Terminal.Core.Absolute_Cell_At (T, Row, Col);
                  begin
                     if Cell.Kind = Terminal.Core.Character
                       and then Cell.Text.Code_Point /= 0
                     then
                        Append_Code_Point (Cell.Text.Code_Point);
                        for I in 1 .. Cell.Text.Attachment_Count loop
                           Append_Code_Point (Cell.Text.Attachments (I));
                        end loop;
                     elsif Cell.Kind = Terminal.Core.Empty then
                        Append_Byte (Character'Pos (' '));
                     end if;
                  end;
               end loop;
            end if;
            while Length > Row_Length and then Buffer (Length) = ' ' loop
               Length := Length - 1;
            end loop;
            if Row < Last_Row and then Length < Buffer'Last then
               Append_Byte (Character'Pos (ASCII.LF));
            end if;
         end;
      end loop;
      while Length > 0 and then Buffer (Length) in ' ' | ASCII.LF loop
         Length := Length - 1;
      end loop;
      return (if Length = 0 then "" else Buffer (1 .. Length));
   end Command_Text;

   function Recommended_Offset
     (T     : Terminal.Core.Terminal;
      Block : Terminal.Core.Shell_Command_Block) return Natural
   is
      Produced : constant Natural := Terminal.Core.History_Rows_Produced (T);
   begin
      if not Block.Has_Prompt or else Block.Prompt_Row > Produced then
         return 0;
      end if;
      return Natural'Min
        (Terminal.Core.Scrollback_Row_Count (T), Produced - Block.Prompt_Row + 1);
   end Recommended_Offset;

   procedure Visible_Range
     (T       : Terminal.Core.Terminal;
      Block   : Terminal.Core.Shell_Command_Block;
      Offset  : Natural;
      First   : out Terminal.App.Selection.Cell_Position;
      Last    : out Terminal.App.Selection.Cell_Position;
      Visible : out Boolean)
   is
      Produced : constant Natural := Terminal.Core.History_Rows_Produced (T);
      Rows : constant Positive := Terminal.Core.Terminal_Row_Count (T);
      Cols : constant Positive := Terminal.Core.Terminal_Column_Count (T);
      Top : constant Natural :=
        (if Offset = 0 then
           (if Produced = Natural'Last then Natural'Last else Produced + 1)
         else Produced - Offset + 1);
      Bottom : constant Natural :=
        (if Top > Natural'Last - (Rows - 1)
         then Natural'Last else Top + Rows - 1);
      Block_First : constant Natural :=
        (if Block.Has_Prompt then Block.Prompt_Row else Block.Input_Row);
      Block_Last : constant Natural :=
        (if Block.Complete then Block.Completion_Row
         elsif Block.Has_Output then Block.Output_Row else Block.Input_Row);
      Visible_First : Natural;
      Visible_Last : Natural;
   begin
      Visible := Block.Has_Input and then Block_Last >= Top
        and then Block_First <= Bottom;
      if not Visible then
         First := (others => 1);
         Last := (others => 1);
         return;
      end if;
      Visible_First := Natural'Max (Block_First, Top);
      Visible_Last := Natural'Min (Block_Last, Bottom);
      First :=
        (Row => Positive (Visible_First - Top + 1),
         Col =>
           (if Visible_First = Block.Prompt_Row and then Block.Has_Prompt
            then Block.Prompt_Col
            elsif Visible_First = Block.Input_Row then Block.Input_Col
            else 1));
      Last :=
        (Row => Positive (Visible_Last - Top + 1),
         Col =>
           (if Visible_Last = Block.Completion_Row
            then Positive'Min (Cols, Block.Completion_Col)
            else Cols));
   end Visible_Range;

   function Status_Label (Block : Terminal.Core.Shell_Command_Block) return String is
      function Image (Value : Natural) return String
        renames Terminal.Common.Status.Trimmed_Natural;
      function Signed_Image (Value : Integer) return String is
        Raw : constant String := Integer'Image (Value);
      begin
         return (if Raw (Raw'First) = ' ' then Raw (Raw'First + 1 .. Raw'Last) else Raw);
      end Signed_Image;
   begin
      if not Block.Has_Input then
         return "No shell command block";
      end if;
      return
        "Command #" & Image (Block.Sequence)
        & (if Block.Has_Exit_Status then " exit=" & Signed_Image (Block.Exit_Status) else "")
        & (if Block.Has_Duration
           then " duration=" & Image (Block.Duration_Milliseconds) & "ms" else "");
   end Status_Label;
end Terminal.App.Shell_Blocks;
