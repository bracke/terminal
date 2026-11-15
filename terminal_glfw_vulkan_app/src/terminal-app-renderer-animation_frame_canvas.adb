with Interfaces;
with Terminal.Common.Bytes;
with Terminal.App.Renderer.Animations;

package body Terminal.App.Renderer.Animation_Frame_Canvas is
   package Animation_State renames Terminal.App.Renderer.Animations;
   use type Interfaces.Unsigned_32;

   procedure Prepare
     (Object        : Image_Object_Access;
      Target_Number : Positive;
      New_Frame     : Boolean;
      Header        : Terminal.App.Graphics.Graphics_Header;
      Canvas        : in out Terminal.App.Owned_Image_Data.Owner;
      Success       : out Boolean;
      Failure       : out Terminal.Core.Graphics_Completion_Code)
   is
      Copied : Boolean := False;

      procedure Copy_Frame
        (Bytes : in out Terminal.Common.Bytes.Byte_Array) is
      begin
         Animation_State.Copy_Frame_To_RGBA
           (Object,
            (if New_Frame and then Header.Kitty_Base_Frame > 0
             then Positive (Header.Kitty_Base_Frame)
             else Target_Number),
            Bytes,
            Copied);
      end Copy_Frame;
   begin
      Success := False;
      Failure := Terminal.Core.Graphics_EINVAL;
      if New_Frame and then Header.Kitty_Base_Frame > 0 then
         if not Animation_State.Frame_Exists
           (Object, Header.Kitty_Base_Frame)
         then
            Failure := Terminal.Core.Graphics_ENOENT;
            return;
         end if;
         Terminal.App.Owned_Image_Data.Modify (Canvas, Copy_Frame'Access);
         Success := Copied;
         return;
      elsif not New_Frame then
         Terminal.App.Owned_Image_Data.Modify (Canvas, Copy_Frame'Access);
         Success := Copied;
         return;
      end if;

      declare
         Color : constant Terminal.Core.Graphics_ID :=
           Header.Kitty_Background_Color;
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
         procedure Fill (Bytes : in out Terminal.Common.Bytes.Byte_Array) is
         begin
            for Pixel in 0 .. Object.Pixel_Width * Object.Pixel_Height - 1 loop
               Bytes (Pixel * 4 + 1) := Red;
               Bytes (Pixel * 4 + 2) := Green;
               Bytes (Pixel * 4 + 3) := Blue;
               Bytes (Pixel * 4 + 4) := Alpha;
            end loop;
         end Fill;
      begin
         Terminal.App.Owned_Image_Data.Modify (Canvas, Fill'Access);
      end;
      Success := True;
   end Prepare;
end Terminal.App.Renderer.Animation_Frame_Canvas;
