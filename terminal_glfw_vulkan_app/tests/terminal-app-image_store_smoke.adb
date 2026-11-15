with Terminal.App.Image_Data;
with Terminal.App.Owned_Image_Data.Unsafe;
with Ada.Real_Time;
with AUnit.Assertions;

with Terminal.App.Image_Store;
with Terminal.App.Image_Store.Frames;
with Terminal.App.Image_Store.Playback_State;
with Terminal.App.Image_Store.Themes;
with Terminal.App.Image_Store.Testing;
with Terminal.App.Image_Animation;
with Terminal.App.Owned_Image_Data;
with Terminal.App.Render_Model;
with Terminal.Common.Bytes;
with Terminal.Core;

procedure Terminal.App.Image_Store_Smoke is
   use AUnit.Assertions;
   use type Terminal.App.Image_Store.Image_Object_Access;
   use type Terminal.App.Image_Data.Image_Data_Access;
   use type Terminal.App.Render_Model.Image_Data_View;
   use type Terminal.Common.Bytes.Byte_Array;
   use type Terminal.App.Image_Store.Image_Frame_Access;
   use type Terminal.App.Image_Store.Theme_Operation_Access;
   use type Terminal.App.Image_Store.Animation_Playback_State;
   use type Terminal.App.Image_Animation.Control_Result;

   package Store renames Terminal.App.Image_Store;
   package Frames renames Terminal.App.Image_Store.Frames;
   package Playback renames Terminal.App.Image_Store.Playback_State;
   package Themes renames Terminal.App.Image_Store.Themes;
   package Store_Testing renames Terminal.App.Image_Store.Testing;

   procedure Install_Root
     (Container        : in out Store.Store;
      Object           : Store.Image_Object_Access;
      Stream_ID        : Terminal.Core.Graphics_Stream_ID;
      ID               : Terminal.Core.Graphics_ID;
      Number           : Terminal.Core.Graphics_ID;
      Protocol         : Terminal.App.Render_Model.Image_Protocol;
      Raw_Format       : Natural;
      Pixel_Width      : Natural;
      Pixel_Height     : Natural;
      Decoded_Length   : Natural;
      Row_Stride       : Natural;
      Usage_Hint       : Natural;
      Data             : in out Terminal.App.Image_Data.Image_Data_Access;
      Index_Control    : access Store.Allocation_Control := null)
   is
      Owner : Terminal.App.Owned_Image_Data.Owner;
   begin
      Terminal.App.Owned_Image_Data.Unsafe.Adopt (Owner, Data);
      Store.Install_Root
        (Container, Object, Stream_ID, ID, Number, Protocol, Raw_Format,
         Pixel_Width, Pixel_Height, Decoded_Length, Row_Stride, Usage_Hint,
         Owner, Index_Control);
   exception
      when others =>
         Terminal.App.Owned_Image_Data.Unsafe.Take (Owner, Data);
         raise;
   end Install_Root;

   procedure Create_Frame
     (Number     : Positive;
      Gap_MS     : Integer;
      Usage_Hint : Natural;
      Data       : in out Terminal.App.Image_Data.Image_Data_Access;
      Frame      : out Store.Image_Frame_Access)
   is
      Owner : Terminal.App.Owned_Image_Data.Owner;
   begin
      Terminal.App.Owned_Image_Data.Unsafe.Adopt (Owner, Data);
      Frames.Create (Number, Gap_MS, Usage_Hint, Owner, Frame);
   exception
      when others =>
         Terminal.App.Owned_Image_Data.Unsafe.Take (Owner, Data);
         raise;
   end Create_Frame;

   procedure Create_Theme
     (Description : Store.Theme_Operation_Descriptor;
      Data        : in out Terminal.App.Image_Data.Image_Data_Access;
      Operation   : out Store.Theme_Operation_Access)
   is
      Owner : Terminal.App.Owned_Image_Data.Owner;
   begin
      Terminal.App.Owned_Image_Data.Unsafe.Adopt (Owner, Data);
      Themes.Create (Description, Owner, Operation);
   exception
      when others =>
         Terminal.App.Owned_Image_Data.Unsafe.Take (Owner, Data);
         raise;
   end Create_Theme;

   function RGBA_Theme_Description
     (Target_Frame : Positive) return Store.Theme_Operation_Descriptor is
     ((Target_Frame          => Target_Frame,
       Raw_Format            => 32,
       Data_Width            => 1,
       Data_Height           => 1,
       Data_Row_Stride_Bytes => 4,
       others                => <>));

   procedure Run_Index_And_Data_Cases is separate;
   procedure Run_Object_And_Theme_Cases is separate;
   procedure Run_Frame_Cases is separate;
   procedure Run_Final_Replacement_Cases is separate;
begin
   Run_Index_And_Data_Cases;
   Run_Object_And_Theme_Cases;
   Run_Frame_Cases;
   Run_Final_Replacement_Cases;
end Terminal.App.Image_Store_Smoke;
