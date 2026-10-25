with Ada.Real_Time;
with Terminal.App.Graphics;
with Terminal.App.Image_Media;
with Terminal.App.Image_Store;
with Terminal.Core;

package Terminal.App.Image_Animation is
   --  Apply Kitty's animation-control action to an already resolved image.
   --  Object lookup and renderer cache invalidation remain with the caller;
   --  playback state transitions belong to this package.
   function Apply_Control
     (Object : Terminal.App.Image_Store.Image_Object_Access;
      Header : Terminal.App.Graphics.Graphics_Header)
      return Terminal.Core.Kitty_Graphics_Result_Code;

   --  Advance one image to Now and return its visible frame transitions.
   --  Work is bounded by the current frame count.
   function Advance
     (Object : Terminal.App.Image_Store.Image_Object_Access;
      Now    : Ada.Real_Time.Time) return Natural;

   --  Materialize the non-root frames of a decoded animated image and
   --  transfer the complete list to the store as one atomic operation.
   procedure Adopt_Decoded_Frames
     (Container : in out Terminal.App.Image_Store.Store;
      Object    : Terminal.App.Image_Store.Image_Object_Access;
      Media     : Terminal.App.Image_Media.Decoded_Image;
      Control   : in out Terminal.App.Image_Store.Allocation_Control;
      Success   : out Boolean);
end Terminal.App.Image_Animation;
