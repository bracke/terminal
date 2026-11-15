with Terminal.App.Image_Store;
with Terminal.App.Image_Store.Frames;
with Terminal.App.Image_Store.Themes;
with Terminal.App.Renderer.Animations;
with Terminal.App.Renderer.Image_Objects;
with Terminal.App.Renderer.Visual_Style;
with Terminal.App.Owned_Image_Data;

package body Terminal.App.Renderer.Theme_State is
   package RM renames Terminal.App.Render_Model;
   package Themes renames Terminal.App.Image_Store.Themes;
   package Frames renames Terminal.App.Image_Store.Frames;
   package Animation_State renames Terminal.App.Renderer.Animations;
   package Image_Objects renames Terminal.App.Renderer.Image_Objects;
   package Style renames Terminal.App.Renderer.Visual_Style;

   use type Terminal.App.Image_Store.Image_Frame_Access;
   use type Interfaces.Unsigned_32;
   use type Terminal.App.Image_Store.Image_Object_Access;
   use type Terminal.App.Image_Store.Theme_Operation_Access;
   use type Terminal.App.Render_Model.Image_Data_View;

   Max_Theme_Operations : constant Natural :=
     Max_Kitty_Animation_Frames * 4;

   procedure Release_Theme_Operation_List
     (Head : in out Theme_Operation_Access) is
   begin
      Themes.Release_Unowned (Head);
   end Release_Theme_Operation_List;

   function Can_Stage_Theme_Operations
     (R          : Renderer;
      Object     : Image_Object_Access;
      Byte_Count : Natural;
      Op_Count   : Natural) return Boolean
   is
      Existing : Natural;
   begin
      if Object = null
        or else Op_Count > Max_Theme_Operations -
          Natural'Min (Themes.Count (Object), Max_Theme_Operations)
      then
         return False;
      end if;
      Existing := Terminal.App.Image_Store.Owned_Bytes (Object.all);
      if Byte_Count > R.Graphics_State.Policy.Limits.Per_Image_Bytes
        or else Existing >
          R.Graphics_State.Policy.Limits.Per_Image_Bytes - Byte_Count
        or else Byte_Count > R.Graphics_State.Policy.Limits.Image_Bytes
      then
         return False;
      end if;
      --  Staging validation is deliberately side-effect free. The caller may still
      --  reject the operation while decoding or allocating its working
      --  canvas; evicting here made malformed animation updates discard
      --  unrelated cached images.  Actual eviction is performed by the final
      --  commit plan once every fallible preparation step has succeeded.
      return True;
   end Can_Stage_Theme_Operations;

   function Prepare_Theme_Baseline
     (Object          : Image_Object_Access;
      Head            : out Theme_Operation_Access;
      Tail            : out Theme_Operation_Access;
      Required_Bytes  : out Natural;
      Required_Count  : out Natural) return Boolean
   is separate;

   function Prepare_Theme_Frame_Operation
     (R             : in out Renderer;
      Object        : Image_Object_Access;
      Header        : Terminal.App.Graphics.Graphics_Header;
      Data          : Terminal.App.Graphics.Graphics_Data_Preview;
      Target_Number : Positive;
      New_Frame     : Boolean;
      Operation     : out Theme_Operation_Access) return Boolean
   is separate;

   function Prepare_Theme_Composition_Operation
     (R           : in out Renderer;
      Object      : Image_Object_Access;
      Header      : Terminal.App.Graphics.Graphics_Header;
      Source      : Positive;
      Target      : Positive;
      Width       : Natural;
      Height      : Natural;
      Operation   : out Theme_Operation_Access) return Boolean
   is separate;

   function Replay_Theme_Operations
     (R      : in out Renderer;
      Object : Image_Object_Access) return Boolean
   is separate;
end Terminal.App.Renderer.Theme_State;
