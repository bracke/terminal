separate (Terminal.App.Renderer.Theme_State.Replay_Theme_Operations)
procedure Apply_Data_Operation
  (Context   : in out Replay_Context;
   R         : in out Renderer;
   Object    : Image_Object_Access;
   Operation : Terminal.App.Image_Store.Theme_Operation_Descriptor;
   Position  : Themes.Cursor)
is
   Target_Data : constant access Terminal.App.Owned_Image_Data.Owner :=
     Target_Bytes
       (Context, Object, Operation.Target_Frame,
        Create => Operation.New_Frame);
   Bytes_Per_Pixel : constant Natural :=
     (if Operation.Raw_Format = 8 then 1
      elsif Operation.Raw_Format = 16 then 2
      elsif Operation.Raw_Format in 24 | 32
      then Operation.Raw_Format / 8
      else 0);
   Operation_Applied : Boolean := False;
   Operation_Visited : Boolean;

   procedure Apply_Operation_Data
     (Operation_Data : Terminal.Common.Bytes.Byte_Array)
   is
      Loaded : Boolean;
      procedure Apply_Data
        (Canvas : in out Terminal.Common.Bytes.Byte_Array) is
      begin
         for Y in 0 .. Operation.Data_Height - 1 loop
            for X in 0 .. Operation.Data_Width - 1 loop
               declare
                  SI : constant Positive := Positive
                    (Y * Operation.Data_Row_Stride_Bytes
                     + X * Bytes_Per_Pixel + 1);
                  DI : constant Positive := Positive
                    (((Operation.Target_Y + Y) * Object.Pixel_Width
                      + Operation.Target_X + X) * 4 + 1);
                  Palette : constant RM.Pixel_Color :=
                    (if Operation.Raw_Format in 8 | 16
                     then Style.Kitty_Indexed_Color
                       (R, Natural (Operation_Data (SI)))
                     else (0.0, 0.0, 0.0, 1.0));
                  SR : constant Natural :=
                    (if Operation.Raw_Format in 8 | 16
                     then Natural (Style.Color_Byte (Palette.R))
                     else Natural (Operation_Data (SI)));
                  SG : constant Natural :=
                    (if Operation.Raw_Format in 8 | 16
                     then Natural (Style.Color_Byte (Palette.G))
                     else Natural (Operation_Data (SI + 1)));
                  SB : constant Natural :=
                    (if Operation.Raw_Format in 8 | 16
                     then Natural (Style.Color_Byte (Palette.B))
                     else Natural (Operation_Data (SI + 2)));
                  SA : constant Natural :=
                    (if Operation.Raw_Format = 16
                     then Natural (Operation_Data (SI + 1))
                     elsif Operation.Raw_Format = 32
                     then Natural (Operation_Data (SI + 3))
                     else 255);
               begin
                  Pixels.Composite_Pixel
                    (Canvas, Canvas'First + DI - 1,
                     SR, SG, SB, SA, Operation.Composition_Mode);
               end;
            end loop;
         end loop;
      end Apply_Data;
   begin
      if Target_Data = null then
         raise Replay_Rejected;
      end if;
      if Operation.New_Frame then
         if Operation.Base_Frame > 0
           and then
             (if Operation.Archived_Frames
              then Target_Bytes
                (Context, Object, Positive (Operation.Base_Frame)) /= null
              else Animation_State.Frame_Exists
                (Object, Operation.Base_Frame))
         then
            Load_Canvas
              (Context, Object, Positive (Operation.Base_Frame),
               Context.Canvas_A, Loaded);
            if not Loaded then
               raise Replay_Rejected;
            end if;
         else
            Set_Background
              (Object, Context.Canvas_A, Operation.Background_Color);
         end if;
      else
         Load_Canvas
           (Context, Object, Operation.Target_Frame,
            Context.Canvas_A, Loaded);
         if not Loaded then
            raise Replay_Rejected;
         end if;
      end if;

      if not Themes.Data_Description_Valid
           (Operation, Operation_Data'Length)
        or else Operation.Target_X > Object.Pixel_Width
        or else Operation.Target_Y > Object.Pixel_Height
        or else Operation.Data_Width >
          Object.Pixel_Width - Operation.Target_X
        or else Operation.Data_Height >
          Object.Pixel_Height - Operation.Target_Y
      then
         raise Replay_Rejected;
      end if;

      Terminal.App.Owned_Image_Data.Modify
        (Context.Canvas_A, Apply_Data'Access);
      Copy_Canvas (Context.Canvas_A, Target_Data, Loaded);
      if not Loaded then
         raise Replay_Rejected;
      end if;
      Operation_Applied := True;
   end Apply_Operation_Data;
begin
   Operation_Visited := Themes.Visit_Data
     (Context.Data_Pin, Position, Apply_Operation_Data'Access);
   if not Operation_Visited or else not Operation_Applied then
      raise Replay_Rejected;
   end if;
end Apply_Data_Operation;
