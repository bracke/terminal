with Ada.Real_Time;
with Terminal.App.Graphics;
with Terminal.App.Image_Store.Frames;
with Terminal.App.Owned_Image_Data;
with Terminal.Common.Bytes;
with Terminal.Core;

private package Terminal.App.Renderer.Animations is
   procedure Composite_Frame
     (R      : in out Renderer;
      Object : Image_Object_Access;
      Header : Terminal.App.Graphics.Graphics_Header;
      Data   : Terminal.App.Graphics.Graphics_Data_Preview;
      Canvas : in out Terminal.App.Owned_Image_Data.Owner);
   procedure Apply_Frame
     (R      : in out Renderer;
      Event  : Terminal.Core.Graphics_Event;
      Header : Terminal.App.Graphics.Graphics_Header;
      Text   : String;
      Allow_Unknown_Compressed_PNG_Size : Boolean := False);
   procedure Apply_Composition
     (R      : in out Renderer;
      Event  : Terminal.Core.Graphics_Event;
      Header : Terminal.App.Graphics.Graphics_Header);

   function Frame_Info
     (Object : Image_Object_Access;
      Number : Positive)
      return Terminal.App.Image_Store.Frames.Frame_Descriptor;
   function Frame_Exists
     (Object : Image_Object_Access;
      Number : Natural) return Boolean;
   procedure Visit_Frame_Bytes
     (Object : Image_Object_Access;
      Number : Positive;
      Borrow : in out Terminal.App.Image_Store.Data_Borrow;
      Process : not null access procedure
        (Data : Terminal.Common.Bytes.Byte_Array));
   function Set_Frame_Gap
     (R      : in out Renderer;
      Object : Image_Object_Access;
      Number : Positive;
      Gap    : Integer) return Boolean;
   function Set_Frame_Usage_Hint
     (R      : in out Renderer;
      Object : Image_Object_Access;
      Number : Positive;
      Value  : Natural) return Boolean;
   procedure Copy_Frame_To_RGBA
     (Object : Image_Object_Access;
      Number : Positive;
      Target : in out Terminal.Common.Bytes.Byte_Array;
      Valid  : out Boolean);

   procedure Visit_Display_Bytes
     (Object : Image_Object_Access;
      Borrow : in out Terminal.App.Image_Store.Data_Borrow;
      Process : not null access procedure
        (Data : Terminal.Common.Bytes.Byte_Array));
   function Display_Frame (Object : Image_Object_Access) return Positive;
   function Display_Format (Object : Image_Object_Access) return Natural;
   function Display_Length (Object : Image_Object_Access) return Natural;
   function Display_Stride (Object : Image_Object_Access) return Natural;

   procedure Delete_Frames
     (R : in out Renderer; Object : Image_Object_Access);
   procedure Apply_Control
     (R      : in out Renderer;
      Event  : Terminal.Core.Graphics_Event;
      Header : Terminal.App.Graphics.Graphics_Header);
   function Frame_Due
     (R   : in out Renderer;
      Now : Ada.Real_Time.Time) return Boolean;
   function Frame_Due (R : in out Renderer) return Boolean;
   function Wait_Duration
     (R       : in out Renderer;
      Now     : Ada.Real_Time.Time;
      Maximum : Duration) return Duration;
   procedure Advance
     (R   : in out Renderer;
      Now : Ada.Real_Time.Time);
   procedure Advance (R : in out Renderer);
end Terminal.App.Renderer.Animations;
