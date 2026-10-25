with Ada.Real_Time;
with Terminal.App.Image_Media;
with Terminal.App.Image_Store;

package Terminal.App.Image_Animation is
   type Control_State is (Unchanged, Stopped, Loading, Running);

   type Animation_Control is record
      Frame_Number : Natural := 0;
      Frame_Gap    : Integer := 0;
      Start_Frame  : Natural := 0;
      Loop_Count   : Natural := 0;
      State        : Control_State := Unchanged;
   end record;

   type Control_Result is (Control_Ok, Control_Invalid, Control_Not_Found);

   --  Apply a protocol-neutral animation-control request to an already
   --  resolved image.  Object lookup, wire-format validation and renderer
   --  cache invalidation remain with the caller.
   function Apply_Control
     (Object : Terminal.App.Image_Store.Image_Object_Access;
      Control : Animation_Control) return Control_Result;

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
