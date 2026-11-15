with Interfaces;

package body Terminal.App.Renderer.Theme_Pixels is
   use type Interfaces.Unsigned_32;
   procedure Fill_Background
     (Target : in out Terminal.Common.Bytes.Byte_Array;
      Width  : Positive;
      Height : Positive;
      Color  : Terminal.Core.Graphics_ID)
   is
      Red : constant Terminal.Common.Bytes.Byte :=
        Terminal.Common.Bytes.Byte
          (Interfaces.Shift_Right (Interfaces.Unsigned_32 (Color), 24));
      Green : constant Terminal.Common.Bytes.Byte :=
        Terminal.Common.Bytes.Byte
          (Interfaces.Shift_Right (Interfaces.Unsigned_32 (Color), 16)
           and 16#FF#);
      Blue : constant Terminal.Common.Bytes.Byte :=
        Terminal.Common.Bytes.Byte
          (Interfaces.Shift_Right (Interfaces.Unsigned_32 (Color), 8)
           and 16#FF#);
      Alpha : constant Terminal.Common.Bytes.Byte :=
        Terminal.Common.Bytes.Byte
          (Interfaces.Unsigned_32 (Color) and 16#FF#);
   begin
      if Width > Natural'Last / Height
        or else Width * Height > Target'Length / 4
      then
         raise Constraint_Error with "theme background canvas is truncated";
      end if;
      for Pixel in 0 .. Width * Height - 1 loop
         Target (Target'First + Pixel * 4) := Red;
         Target (Target'First + Pixel * 4 + 1) := Green;
         Target (Target'First + Pixel * 4 + 2) := Blue;
         Target (Target'First + Pixel * 4 + 3) := Alpha;
      end loop;
   end Fill_Background;

   procedure Composite_Pixel
     (Target : in out Terminal.Common.Bytes.Byte_Array;
      Index  : Positive;
      SR     : Natural;
      SG     : Natural;
      SB     : Natural;
      SA     : Natural;
      Mode   : Natural) is
   begin
      if Target'Length < 4
        or else Index < Target'First
        or else Index > Target'Last - 3
        or else SR > 255 or else SG > 255 or else SB > 255 or else SA > 255
        or else Mode > 1
      then
         raise Constraint_Error with "invalid theme pixel composition";
      elsif Mode = 1 or else SA = 255 then
         Target (Index) := Terminal.Common.Bytes.Byte (SR);
         Target (Index + 1) := Terminal.Common.Bytes.Byte (SG);
         Target (Index + 2) := Terminal.Common.Bytes.Byte (SB);
         Target (Index + 3) := Terminal.Common.Bytes.Byte (SA);
      elsif SA > 0 then
         declare
            DR : constant Natural := Natural (Target (Index));
            DG : constant Natural := Natural (Target (Index + 1));
            DB : constant Natural := Natural (Target (Index + 2));
            DA : constant Natural := Natural (Target (Index + 3));
            OA : constant Natural := SA + (DA * (255 - SA) + 127) / 255;
            Denom : constant Natural := Natural'Max (1, OA * 255);
         begin
            Target (Index) := Terminal.Common.Bytes.Byte
              ((SR * SA * 255 + DR * DA * (255 - SA) + Denom / 2) / Denom);
            Target (Index + 1) := Terminal.Common.Bytes.Byte
              ((SG * SA * 255 + DG * DA * (255 - SA) + Denom / 2) / Denom);
            Target (Index + 2) := Terminal.Common.Bytes.Byte
              ((SB * SA * 255 + DB * DA * (255 - SA) + Denom / 2) / Denom);
            Target (Index + 3) := Terminal.Common.Bytes.Byte (OA);
         end;
      end if;
   end Composite_Pixel;

   procedure Composite_Region
     (Target        : in out Terminal.Common.Bytes.Byte_Array;
      Source        : Terminal.Common.Bytes.Byte_Array;
      Canvas_Width  : Positive;
      Source_X      : Natural;
      Source_Y      : Natural;
      Target_X      : Natural;
      Target_Y      : Natural;
      Region_Width  : Positive;
      Region_Height : Positive;
      Mode          : Natural)
   is
      Row_Bytes : Natural;
      Canvas_Height : Natural;
   begin
      if Canvas_Width > Natural'Last / 4 then
         raise Constraint_Error with "theme canvas row is too wide";
      end if;
      Row_Bytes := Canvas_Width * 4;
      if Target'Length < Row_Bytes
        or else Target'Length mod Row_Bytes /= 0
        or else Source'Length /= Target'Length
      then
         raise Constraint_Error with "theme canvas extent is invalid";
      end if;
      Canvas_Height := Target'Length / Row_Bytes;
      if Source_X >= Canvas_Width
        or else Target_X >= Canvas_Width
        or else Source_Y >= Canvas_Height
        or else Target_Y >= Canvas_Height
        or else Region_Width > Canvas_Width - Source_X
        or else Region_Width > Canvas_Width - Target_X
        or else Region_Height > Canvas_Height - Source_Y
        or else Region_Height > Canvas_Height - Target_Y
        or else Mode > 1
      then
         raise Constraint_Error with "theme composition region is invalid";
      end if;
      for Y in 0 .. Region_Height - 1 loop
         for X in 0 .. Region_Width - 1 loop
            declare
               SI : constant Positive := Positive
                 (((Source_Y + Y) * Canvas_Width + Source_X + X) * 4 + 1);
               DI : constant Positive := Positive
                 (((Target_Y + Y) * Canvas_Width + Target_X + X) * 4 + 1);
            begin
               Composite_Pixel
                 (Target,
                  Target'First + DI - 1,
                  Natural (Source (Source'First + SI - 1)),
                  Natural (Source (Source'First + SI)),
                  Natural (Source (Source'First + SI + 1)),
                  Natural (Source (Source'First + SI + 2)),
                  Mode);
            end;
         end loop;
      end loop;
   end Composite_Region;
end Terminal.App.Renderer.Theme_Pixels;
