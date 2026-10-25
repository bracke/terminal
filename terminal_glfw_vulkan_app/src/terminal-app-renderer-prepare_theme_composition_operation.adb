separate (Terminal.App.Renderer)
function Prepare_Theme_Composition_Operation
  (R           : in out Renderer;
   Object      : Image_Object_Access;
   Header      : Terminal.App.Graphics.Graphics_Header;
   Source      : Positive;
   Target      : Positive;
   Width       : Natural;
   Height      : Natural;
   Operation   : out Theme_Operation_Access) return Boolean
is
   Data : RM.Image_Data_Access := null;
   Description : constant Terminal.App.Image_Store.Theme_Operation_Descriptor :=
     (Is_Composition   => True,
      Target_Frame     => Target,
      Source_Frame     => Source,
      Target_X         => Header.Kitty_Source_X,
      Target_Y         => Header.Kitty_Source_Y,
      Source_X         => Header.Kitty_Cell_X,
      Source_Y         => Header.Kitty_Cell_Y,
      Region_Width     => Width,
      Region_Height    => Height,
      Composition_Mode => Header.Kitty_Composition_Mode,
      others           => <>);
begin
   Operation := null;
   if Object = null
     or else
       (Themes.First (Object) = null
        and then Terminal.App.Image_Store.Indexed_Data (Object) = null)
   then
      return True;
   end if;
   if not Ensure_Theme_Baseline (R, Object)
     or else not Reserve_Theme_Operation_Bytes (R, Object, 0, 1)
   then
      return False;
   end if;
   Themes.Create
     (Description, Data, Operation);
   return True;
exception
   when Storage_Error =>
      Themes.Release_Unowned (Operation);
      raise;
   when Constraint_Error =>
      Themes.Release_Unowned (Operation);
      return False;
end Prepare_Theme_Composition_Operation;
