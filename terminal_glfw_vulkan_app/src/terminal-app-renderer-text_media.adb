with Interfaces;
with Terminal.App.Graphics;
with Terminal.App.Renderer.Visual_Style;
with Terminal.App.Size_Arithmetic;
with Terminal.App.Text_Shaper;

package body Terminal.App.Renderer.Text_Media is
   package RM renames Terminal.App.Render_Model;
   package Style renames Terminal.App.Renderer.Visual_Style;
   use type Terminal.Core.Cell_Kind;
   use type Terminal.Core.Cell_Width;
   use type Terminal.Core.Style;
   use type RM.Text_Run_Direction;
   use type RM.Text_Run_Script;
   use type Textrender.Status_Code;

   function Ceiling_Positive (Value : Float) return Positive is
      Maximum : constant Positive := Max_Graphics_Pixel_Dimension - 1;
   begin
      if not (Value >= -Float'Last and then Value <= Float'Last)
        or else Value <= 1.0
      then
         return 1;
      elsif Value >= Float (Maximum) then
         return Maximum;
      else
         return Positive (Float'Ceiling (Value));
      end if;
   end Ceiling_Positive;

   function Measured_Cell_Width
     (Text : in out Textrender.Renderer; Fallback : Positive) return Positive
   is
      Max_Width : Float := Float (Fallback);
   begin
      for C in Character'Pos (' ') .. Character'Pos ('~') loop
         declare
            Metric : Textrender.Glyph_Metric;
            Status : constant Textrender.Status_Code :=
              Textrender.Get_Glyph
                (R => Text, C => Textrender.Codepoint (C), M => Metric);
         begin
            if Status = Textrender.Success
              or else Status = Textrender.Glyph_Missing
            then
               Max_Width := Float'Max
                 (Max_Width, Metric.Bearing_X + Float (Metric.W));
               Max_Width := Float'Max (Max_Width, Metric.Advance_X);
            end if;
         end;
      end loop;
      return Ceiling_Positive (Max_Width) + 1;
   end Measured_Cell_Width;

   function Is_Emoji_Scalar
     (Codepoint : Terminal.Common.Code_Point) return Boolean is
      C : constant Natural := Natural (Codepoint);
   begin
      return (C in 16#1F000# .. 16#1FAFF#)
        or else (C in 16#2600# .. 16#27BF#);
   end Is_Emoji_Scalar;

   function Colour_PNG_Extent
     (Data   : Textrender.Encoded_Image;
      Width  : out Natural;
      Height : out Natural) return Boolean
   is
      use type Interfaces.Unsigned_32;
      function U32_BE (Offset : Natural) return Interfaces.Unsigned_32 is
        (Interfaces.Shift_Left
           (Interfaces.Unsigned_32 (Data (Data'First + Offset)), 24)
         or Interfaces.Shift_Left
           (Interfaces.Unsigned_32 (Data (Data'First + Offset + 1)), 16)
         or Interfaces.Shift_Left
           (Interfaces.Unsigned_32 (Data (Data'First + Offset + 2)), 8)
         or Interfaces.Unsigned_32 (Data (Data'First + Offset + 3)));
      Encoded_Width  : Interfaces.Unsigned_32;
      Encoded_Height : Interfaces.Unsigned_32;
      Pixels         : Natural := 0;
      Bytes          : Natural := 0;
   begin
      Width := 0;
      Height := 0;
      if Data'Length < 24
        or else Natural (Data (Data'First)) /= 16#89#
        or else Natural (Data (Data'First + 1)) /= 16#50#
        or else Natural (Data (Data'First + 2)) /= 16#4E#
        or else Natural (Data (Data'First + 3)) /= 16#47#
        or else Natural (Data (Data'First + 4)) /= 16#0D#
        or else Natural (Data (Data'First + 5)) /= 16#0A#
        or else Natural (Data (Data'First + 6)) /= 16#1A#
        or else Natural (Data (Data'First + 7)) /= 16#0A#
        or else U32_BE (8) /= 13
        or else Character'Val (Natural (Data (Data'First + 12))) /= 'I'
        or else Character'Val (Natural (Data (Data'First + 13))) /= 'H'
        or else Character'Val (Natural (Data (Data'First + 14))) /= 'D'
        or else Character'Val (Natural (Data (Data'First + 15))) /= 'R'
      then
         return False;
      end if;
      Encoded_Width := U32_BE (16);
      Encoded_Height := U32_BE (20);
      if Encoded_Width = 0
        or else Encoded_Height = 0
        or else Encoded_Width > Interfaces.Unsigned_32 (Natural'Last)
        or else Encoded_Height > Interfaces.Unsigned_32 (Natural'Last)
      then
         return False;
      end if;
      Width := Natural (Encoded_Width);
      Height := Natural (Encoded_Height);
      if not Terminal.App.Size_Arithmetic.Try_Multiply
          (Width, Height, Pixels)
        or else not Terminal.App.Size_Arithmetic.Try_Multiply
          (Pixels, 4, Bytes)
        or else Bytes > Terminal.App.Graphics.Max_Data_Preview_Length
      then
         Width := 0;
         Height := 0;
         return False;
      end if;
      return True;
   end Colour_PNG_Extent;

   function Is_Drawable (Cell : Terminal.Core.Cell_Content) return Boolean is
     (Cell.Kind = Terminal.Core.Character
      and then Cell.Text.Width /= Terminal.Core.Width_Zero
      and then Natural (Cell.Text.Code_Point) /= 0
      and then not Cell.Image.Is_Placeholder);

   procedure Cell_Properties
     (Cell      : Terminal.Core.Cell_Content;
      Direction : out RM.Text_Run_Direction;
      Script    : out RM.Text_Run_Script) is
   begin
      Terminal.App.Text_Shaper.Properties_Of
        (Natural (Cell.Text.Code_Point), Direction, Script);
   end Cell_Properties;

   function Cell_Joins_Run
     (Snapshot  : Terminal.Core.Render_Snapshot;
      Row       : Positive;
      Col       : Positive;
      Base      : Terminal.Core.Cell_Content;
      Direction : in out RM.Text_Run_Direction;
      Script    : in out RM.Text_Run_Script) return Boolean
   is
      Cell     : constant Terminal.Core.Cell_Content :=
        Terminal.Core.Cell_Content_At (Snapshot, Row, Col);
      Cell_Dir : RM.Text_Run_Direction;
      Cell_Scr : RM.Text_Run_Script;
      New_Dir  : RM.Text_Run_Direction := Direction;
      New_Scr  : RM.Text_Run_Script := Script;
   begin
      if not Is_Drawable (Cell)
        or else Cell.Style.Conceal
        or else Cell.Kind = Terminal.Core.Wide_Continuation
        or else Cell.Text.Width /= Terminal.Core.Width_One
        or else Cell.Text.Attachment_Count /= 0
        or else Cell.Style /= Base.Style
        or else Style.Is_Block_Cursor (Snapshot, Row, Col)
      then
         return False;
      end if;

      Cell_Properties (Cell, Cell_Dir, Cell_Scr);
      if Cell_Dir /= RM.Direction_Neutral then
         if New_Dir = RM.Direction_Neutral then
            New_Dir := Cell_Dir;
         elsif New_Dir /= Cell_Dir then
            return False;
         end if;
      end if;

      if Cell_Scr /= RM.Script_Common then
         if New_Scr = RM.Script_Common then
            New_Scr := Cell_Scr;
         elsif New_Scr /= Cell_Scr then
            return False;
         end if;
      end if;

      Direction := New_Dir;
      Script := New_Scr;
      return True;
   end Cell_Joins_Run;
end Terminal.App.Renderer.Text_Media;
