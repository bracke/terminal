separate (Terminal.App.Renderer.Theme_State.Replay_Theme_Operations)
procedure Apply_Composition_Operation
  (Context   : in out Replay_Context;
   Object    : Image_Object_Access;
   Operation : Terminal.App.Image_Store.Theme_Operation_Descriptor)
is
   Source_Data : access Terminal.App.Owned_Image_Data.Owner;
   Target_Data : access Terminal.App.Owned_Image_Data.Owner;
   Loaded      : Boolean;

   procedure Blend_Target
     (Target_Bytes : in out Terminal.Common.Bytes.Byte_Array) is
      procedure Blend_Source
        (Source_Bytes : Terminal.Common.Bytes.Byte_Array) is
      begin
         Pixels.Composite_Region
           (Target        => Target_Bytes,
            Source        => Source_Bytes,
            Canvas_Width  => Positive (Object.Pixel_Width),
            Source_X      => Operation.Source_X,
            Source_Y      => Operation.Source_Y,
            Target_X      => Operation.Target_X,
            Target_Y      => Operation.Target_Y,
            Region_Width  => Positive (Operation.Region_Width),
            Region_Height => Positive (Operation.Region_Height),
            Mode          => Operation.Composition_Mode);
      end Blend_Source;
   begin
      Terminal.App.Owned_Image_Data.Read
        (Context.Canvas_A, Blend_Source'Access);
   end Blend_Target;
begin
   if not Themes.Data_Description_Valid (Operation, 0)
     or else Operation.Source_X > Object.Pixel_Width
     or else Operation.Source_Y > Object.Pixel_Height
     or else Operation.Target_X > Object.Pixel_Width
     or else Operation.Target_Y > Object.Pixel_Height
     or else Operation.Region_Width >
       Object.Pixel_Width - Operation.Source_X
     or else Operation.Region_Height >
       Object.Pixel_Height - Operation.Source_Y
     or else Operation.Region_Width >
       Object.Pixel_Width - Operation.Target_X
     or else Operation.Region_Height >
       Object.Pixel_Height - Operation.Target_Y
   then
      raise Replay_Rejected;
   end if;

   Source_Data :=
     Target_Bytes (Context, Object, Operation.Source_Frame);
   Target_Data :=
     Target_Bytes (Context, Object, Operation.Target_Frame);
   if Source_Data = null or else Target_Data = null then
      raise Replay_Rejected;
   end if;

   Load_Canvas
     (Context, Object, Operation.Source_Frame, Context.Canvas_A, Loaded);
   if not Loaded then
      raise Replay_Rejected;
   end if;
   Load_Canvas
     (Context, Object, Operation.Target_Frame, Context.Canvas_B, Loaded);
   if not Loaded then
      raise Replay_Rejected;
   end if;
   Terminal.App.Owned_Image_Data.Modify
     (Context.Canvas_B, Blend_Target'Access);
   Copy_Canvas (Context.Canvas_B, Target_Data, Loaded);
   if not Loaded then
      raise Replay_Rejected;
   end if;
end Apply_Composition_Operation;
