separate (Terminal.App.Renderer)
procedure Add_Image_Event
  (R                     : in out Renderer;
   Event                 : Terminal.Core.Graphics_Event;
   Resolved_Image_ID     : Terminal.Core.Graphics_ID := 0;
   Resolved_Image_Number : Terminal.Core.Graphics_ID := 0)
is
   function Resolved_Header
     (Value : Terminal.App.Graphics.Graphics_Header)
      return Terminal.App.Graphics.Graphics_Header
   is
      Result : Terminal.App.Graphics.Graphics_Header := Value;
   begin
      if Resolved_Image_ID > 0 then
         Result.Kitty_ID := Resolved_Image_ID;
      end if;
      if Resolved_Image_Number > 0 then
         Result.Kitty_Image_Number := Resolved_Image_Number;
      end if;
      return Result;
   end Resolved_Header;

   function Event_Text
     (Item : Terminal.Core.Graphics_Event) return String is
   begin
      return Complete_Event_Text (R, Item);
   end Event_Text;

   function Emit_Raw_Kitty
     (Item       : Terminal.Core.Graphics_Event;
      Header     : Terminal.App.Graphics.Graphics_Header;
      Image_Text : String) return Boolean
   is separate;


   function Emit_Image_Object
     (Item   : Terminal.Core.Graphics_Event;
      Header : Terminal.App.Graphics.Graphics_Header) return Boolean
   is separate;
   type Image_Emit_Result is
     (Emit_Not_Applicable, Emit_Succeeded, Emit_Rejected);

   function Emit_PNG_Rows
     (Item       : Terminal.Core.Graphics_Event;
      Header     : Terminal.App.Graphics.Graphics_Header;
      Image_Text : String;
      Allow_Unknown_Compressed_Size : Boolean := False)
       return Image_Emit_Result
   is separate;

   function Emit_Local_Kitty
     (Item       : Terminal.Core.Graphics_Event;
      Header     : Terminal.App.Graphics.Graphics_Header;
      Image_Text : String) return Boolean
   is separate;

   function Emit_Sixel_Rows
     (Item       : Terminal.Core.Graphics_Event;
      Header     : Terminal.App.Graphics.Graphics_Header;
      Image_Text : String) return Boolean
   is separate;

   procedure Emit_Image
     (Item       : Terminal.Core.Graphics_Event;
      Image_Text : String)
   is separate;

   Text : constant String := Event_Text (Event);
   Header : constant Terminal.App.Graphics.Graphics_Header :=
     Resolved_Header (Terminal.App.Graphics.Header (Event));
begin
   if FIS.Is_Full (R.Frame_Images) then
      R.Frame_Command_Overflowed := True;
      return;
   end if;
   if not Event.Pending
     or else Event.Protocol = Terminal.Core.No_Graphics
   then
      return;
   end if;

   if Event.Protocol = Terminal.Core.ITerm2_Graphics
     and then
       (not Header.ITerm2_Control_Data_Valid
        or else not Header.ITerm2_Inline
        or else not Header.ITerm2_Width_Valid
        or else not Header.ITerm2_Height_Valid)
   then
      --  Non-inline transfers are downloads, which this terminal does not
      --  perform. Invalid display dimensions are ignored atomically.
      return;
   end if;

   if Event.Protocol = Terminal.Core.Kitty_Graphics
     and then Header.Recognized
     and then Header.Kitty_Action = 'd'
     and then not Header.Has_Data
   then
      if Header.Kitty_ID > 0 then
         Delete_Image_Object (R, Event.Stream_ID, Header.Kitty_ID);
      else
         Delete_Virtual_Placements (R, Event.Stream_ID, 0);
         Delete_Conventional_Placements (R, Event.Stream_ID, 0);
      end if;
      return;
   end if;

   if Event.Protocol = Terminal.Core.Kitty_Graphics
     and then Header.Recognized
     and then Header.Kitty_ID > 0
     and then not Header.Has_Data
   then
      --  An addressed display command is either resolved from retained data
      --  or rejected.  It must never fall through to the generic preview
      --  path, whose dimensions are not object-validated.
      declare
         Emitted : constant Boolean := Emit_Image_Object (Event, Header);
      begin
         pragma Unreferenced (Emitted);
         return;
      end;
   end if;

   if Event.Protocol = Terminal.Core.Kitty_Graphics
     and then Header.Recognized
     and then Header.Has_Data
     and then Event.Protocol = Terminal.Core.Kitty_Graphics
     and then Header.Kitty_Transmission in 'f' | 't' | 's'
   then
      if Emit_Local_Kitty (Event, Header, Text) then
         null;
      end if;
      return;
   end if;

   if Header.Recognized
     and then Header.Has_Data
     and then Event.Protocol = Terminal.Core.Kitty_Graphics
     and then Header.Kitty_Action = 'f'
   then
      Apply_Animation_Frame (R, Event, Header, Text);
      return;
   end if;

   if Header.Recognized
     and then Header.Has_Data
     and then Event.Protocol = Terminal.Core.Kitty_Graphics
     and then Header.Kitty_Format in 8 | 16 | 24 | 32
     and then Emit_Raw_Kitty (Event, Header, Text)
   then
      return;
   end if;

   if Header.Recognized
     and then Header.Has_Data
     and then
       (Event.Protocol = Terminal.Core.ITerm2_Graphics
        or else
          (Event.Protocol = Terminal.Core.Kitty_Graphics
           and then Header.Kitty_Format = 100))
   then
      case Emit_PNG_Rows (Event, Header, Text) is
         when Emit_Succeeded =>
            return;
         when Emit_Rejected =>
            --  iTerm2's full decoder is authoritative. Kitty retains its
            --  diagnostic placeholder fallback for rejected f=100 data.
            if Event.Protocol = Terminal.Core.ITerm2_Graphics then
               return;
            end if;
         when Emit_Not_Applicable =>
            null;
      end case;
   end if;

   if Header.Recognized
     and then Header.Has_Data
     and then Event.Protocol = Terminal.Core.Sixel_Graphics
     and then Emit_Sixel_Rows (Event, Header, Text)
   then
      return;
   end if;

   Emit_Image (Event, Text);
end Add_Image_Event;
