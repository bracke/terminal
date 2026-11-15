separate (Terminal.App.Renderer.Theme_State)
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
   Data : Terminal.App.Owned_Image_Data.Owner;
   Head : Theme_Operation_Access := null;
   Tail : Theme_Operation_Access := null;
   New_Operation : Theme_Operation_Access := null;
   Baseline_Bytes : Natural := 0;
   Baseline_Count : Natural := 0;
   Description : constant Terminal.App.Image_Store.Theme_Operation_Descriptor :=
     (Is_Composition   => True,
      Target_Frame     => Target,
      Source_Frame     => Source,
      Target_X         => Header.Kitty_Cell_X,
      Target_Y         => Header.Kitty_Cell_Y,
      Source_X         => Header.Kitty_Source_X,
      Source_Y         => Header.Kitty_Source_Y,
      Region_Width     => Width,
      Region_Height    => Height,
      Composition_Mode => Header.Kitty_Composition_Mode,
      others           => <>);
begin
   Operation := null;
   if Object = null
     or else
       (Themes.Count (Object) = 0
        and then not Image_Objects.Has_Stored_Indexed (Object))
   then
      return True;
   end if;
   if Themes.Count (Object) = 0
     and then not Prepare_Theme_Baseline
       (Object, Head, Tail, Baseline_Bytes, Baseline_Count)
   then
      return False;
   end if;
   if Baseline_Count = Natural'Last
     or else not Can_Stage_Theme_Operations
       (R, Object, Baseline_Bytes, Baseline_Count + 1)
   then
      Themes.Release_Unowned (Head);
      return False;
   end if;
   Themes.Create
     (Description, Data, New_Operation);
   Themes.Append_Unowned (Head, Tail, New_Operation);
   Operation := Head;
   return True;
exception
   when Storage_Error =>
      Themes.Release_Unowned (New_Operation);
      Themes.Release_Unowned (Head);
      raise;
   when Constraint_Error =>
      Themes.Release_Unowned (New_Operation);
      Themes.Release_Unowned (Head);
      return False;
end Prepare_Theme_Composition_Operation;
