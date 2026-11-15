with Terminal.App.Graphics;
with Terminal.App.Renderer.Image_Objects;
with Terminal.App.Renderer.Placement_State;

package body Terminal.App.Renderer.Frame_Planning is
   use type Image_Object_Access;
   use type Terminal.App.Render_Model.Image_Protocol;
   use type Terminal.Core.Graphics_ID;
   use type Terminal.Core.Graphics_Protocol_Kind;

   function Additional_Image_Command_Count
     (R     : Renderer;
      Event : Terminal.Core.Graphics_Event) return Natural
   is
      Header : Terminal.App.Graphics.Graphics_Header;
      Image_ID : Terminal.Core.Graphics_ID;
      Numbered_Object : Image_Object_Access;
   begin
      if not Event.Pending or else Event.Protocol = Terminal.Core.No_Graphics then
         return 0;
      elsif Event.Protocol /= Terminal.Core.Kitty_Graphics then
         --  A malformed auxiliary image may remain a one-frame diagnostic
         --  placeholder instead of becoming a retained placement.
         return 1;
      end if;

      Header := Terminal.App.Graphics.Header (Event);
      if not Header.Recognized or else Header.Kitty_Action not in 'p' | 'T' then
         return 0;
      end if;
      Image_ID := Header.Kitty_ID;
      if Image_ID = 0 and then Header.Kitty_Image_Number > 0 then
         Numbered_Object := Image_Objects.Find_By_Number
           (R, Event.Stream_ID, Header.Kitty_Image_Number);
         if Numbered_Object /= null then
            Image_ID := Numbered_Object.ID;
         end if;
      end if;
      if Header.Kitty_Placement_ID = 0
        or else Image_ID = 0
        or else
          (if Header.Kitty_Virtual_Placement
           then not Placement_State.Find_Addressed_Virtual_Placement
             (R, Event.Stream_ID, Image_ID,
              Header.Kitty_Placement_ID).Exists
           else not Placement_State.Find_Addressed_Conventional_Placement
             (R, Event.Stream_ID, Image_ID,
              Header.Kitty_Placement_ID).Exists)
      then
         return 1;
      end if;
      return 0;
   end Additional_Image_Command_Count;
end Terminal.App.Renderer.Frame_Planning;
