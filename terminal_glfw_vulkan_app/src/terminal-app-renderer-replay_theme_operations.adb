separate (Terminal.App.Renderer)
function Replay_Theme_Operations
  (R      : in out Renderer;
   Object : Image_Object_Access) return Boolean
is
   Canvas_Length : Natural;
   Canvas_A : RM.Image_Data_Access := null;
   Canvas_B : RM.Image_Data_Access := null;
   Operation : Theme_Operation_Access;
   Valid : Boolean := False;

   type Archived_Frame_State;
   type Archived_Frame_State_Access is access Archived_Frame_State;
   type Archived_Frame_State is record
      Number : Positive;
      Bytes  : RM.Image_Data_Access := null;
      Next   : Archived_Frame_State_Access := null;
   end record;
   Archived_Frames : Archived_Frame_State_Access := null;
   procedure Free_Archived_Frame is new Ada.Unchecked_Deallocation
     (Archived_Frame_State, Archived_Frame_State_Access);

   procedure Release_Archived_Frames is
      Current : Archived_Frame_State_Access := Archived_Frames;
   begin
      while Current /= null loop
         declare
            Next : constant Archived_Frame_State_Access := Current.Next;
         begin
            Free_Image_Data (Current.Bytes);
            Free_Archived_Frame (Current);
            Current := Next;
         end;
      end loop;
      Archived_Frames := null;
   end Release_Archived_Frames;

   function Target_Bytes
     (Number   : Positive;
      Archived : Boolean;
      Create    : Boolean := False) return RM.Image_Data_Access
   is
      Current : Archived_Frame_State_Access := null;
      New_Bytes : RM.Image_Data_Access := null;
      Copied : Boolean := False;
      pragma Unreferenced (Archived);
   begin
      Current := Archived_Frames;
      while Current /= null loop
         if Current.Number = Number then
            return Current.Bytes;
         end if;
         Current := Current.Next;
      end loop;
      if not Create and then not Animation_Frame_Exists (Object, Number) then
         return null;
      end if;
      --  Allocate the byte storage separately so failure to allocate the
      --  list node cannot orphan an already-created canvas.
      New_Bytes := new Terminal.Common.Bytes.Byte_Array (1 .. Canvas_Length);
      Current := new Archived_Frame_State'
        (Number => Number,
         Bytes  => New_Bytes,
         Next   => Archived_Frames);
      New_Bytes := null;
      if Create then
         Current.Bytes.all := (others => 0);
      else
         Copy_Frame_To_RGBA (Object, Number, Current.Bytes.all, Copied);
         if not Copied then
            Free_Image_Data (Current.Bytes);
            Free_Archived_Frame (Current);
            return null;
         end if;
      end if;
      Archived_Frames := Current;
      return Current.Bytes;
   exception
      when others =>
         Free_Image_Data (New_Bytes);
         if Current /= null then
            Free_Image_Data (Current.Bytes);
            Free_Archived_Frame (Current);
         end if;
         raise;
   end Target_Bytes;

   procedure Copy_Replay_Frame_To_RGBA
     (Number   : Positive;
      Archived : Boolean;
      Target   : in out Terminal.Common.Bytes.Byte_Array;
      Valid    : out Boolean)
   is
      Source : constant RM.Image_Data_Access :=
        Target_Bytes (Number, Archived);
   begin
      Valid := False;
      if Source = null or else Source'Length /= Target'Length then
         return;
      end if;
      Target := Source.all;
      Valid := True;
   end Copy_Replay_Frame_To_RGBA;

   procedure Fill_Background
     (Target : in out Terminal.Common.Bytes.Byte_Array;
      Color  : Terminal.Core.Graphics_ID)
   is
      Red : constant Terminal.Common.Bytes.Byte :=
        Terminal.Common.Bytes.Byte
          (Interfaces.Shift_Right (Interfaces.Unsigned_32 (Color), 24));
      Green : constant Terminal.Common.Bytes.Byte :=
        Terminal.Common.Bytes.Byte
          (Interfaces.Shift_Right (Interfaces.Unsigned_32 (Color), 16)
           and 16#FF#);
      Blue : constant Terminal.Common.Bytes.Byte :=
        Terminal.Common.Bytes.Byte
          (Interfaces.Shift_Right (Interfaces.Unsigned_32 (Color), 8)
           and 16#FF#);
      Alpha : constant Terminal.Common.Bytes.Byte :=
        Terminal.Common.Bytes.Byte
          (Interfaces.Unsigned_32 (Color) and 16#FF#);
   begin
      for Pixel in 0 .. Object.Pixel_Width * Object.Pixel_Height - 1 loop
         Target (Target'First + Pixel * 4) := Red;
         Target (Target'First + Pixel * 4 + 1) := Green;
         Target (Target'First + Pixel * 4 + 2) := Blue;
         Target (Target'First + Pixel * 4 + 3) := Alpha;
      end loop;
   end Fill_Background;

   procedure Composite_Pixel
     (Target : in out Terminal.Common.Bytes.Byte_Array;
      Index  : Positive;
      SR     : Natural;
      SG     : Natural;
      SB     : Natural;
      SA     : Natural;
      Mode   : Natural)
   is
   begin
      if Mode = 1 or else SA = 255 then
         Target (Index) := Terminal.Common.Bytes.Byte (SR);
         Target (Index + 1) := Terminal.Common.Bytes.Byte (SG);
         Target (Index + 2) := Terminal.Common.Bytes.Byte (SB);
         Target (Index + 3) := Terminal.Common.Bytes.Byte (SA);
      elsif SA > 0 then
         declare
            DR : constant Natural := Natural (Target (Index));
            DG : constant Natural := Natural (Target (Index + 1));
            DB : constant Natural := Natural (Target (Index + 2));
            DA : constant Natural := Natural (Target (Index + 3));
            OA : constant Natural := SA + (DA * (255 - SA) + 127) / 255;
            Denom : constant Natural := Natural'Max (1, OA * 255);
         begin
            Target (Index) := Terminal.Common.Bytes.Byte
              ((SR * SA * 255 + DR * DA * (255 - SA) + Denom / 2) /
                 Denom);
            Target (Index + 1) := Terminal.Common.Bytes.Byte
              ((SG * SA * 255 + DG * DA * (255 - SA) + Denom / 2) /
                 Denom);
            Target (Index + 2) := Terminal.Common.Bytes.Byte
              ((SB * SA * 255 + DB * DA * (255 - SA) + Denom / 2) /
                 Denom);
            Target (Index + 3) := Terminal.Common.Bytes.Byte (OA);
         end;
      end if;
   end Composite_Pixel;
begin
   if Object = null
     or else Terminal.App.Image_Store.First_Theme_Operation (Object) = null
   then
      return True;
   elsif Object.Pixel_Width = 0
     or else Object.Pixel_Height = 0
     or else Object.Pixel_Width > Natural'Last / Object.Pixel_Height
     or else Object.Pixel_Width * Object.Pixel_Height > Natural'Last / 4
   then
      return False;
   end if;
   Canvas_Length := Object.Pixel_Width * Object.Pixel_Height * 4;
   Canvas_A := new Terminal.Common.Bytes.Byte_Array (1 .. Canvas_Length);
   Canvas_B := new Terminal.Common.Bytes.Byte_Array (1 .. Canvas_Length);
   Operation := Terminal.App.Image_Store.First_Theme_Operation (Object);
   while Operation /= null loop
      if Operation.Is_Composition then
         declare
            Source_Data : constant RM.Image_Data_Access :=
              Target_Bytes
                (Positive (Operation.Source_Frame),
                 Operation.Archived_Frames);
            Target_Data : constant RM.Image_Data_Access :=
              Target_Bytes
                (Operation.Target_Frame,
                 Operation.Archived_Frames);
         begin
            if Source_Data /= null and then Target_Data /= null then
               Copy_Replay_Frame_To_RGBA
                 (Positive (Operation.Source_Frame),
                  Operation.Archived_Frames,
                  Canvas_A.all,
                  Valid);
               if not Valid then
                  Free_Image_Data (Canvas_A);
                  Free_Image_Data (Canvas_B);
                  Release_Archived_Frames;
                  return False;
               end if;
               Copy_Replay_Frame_To_RGBA
                 (Operation.Target_Frame,
                  Operation.Archived_Frames,
                  Canvas_B.all,
                  Valid);
               if not Valid then
                  Free_Image_Data (Canvas_A);
                  Free_Image_Data (Canvas_B);
                  Release_Archived_Frames;
                  return False;
               end if;
               for Y in 0 .. Operation.Region_Height - 1 loop
                  for X in 0 .. Operation.Region_Width - 1 loop
                     declare
                        SI : constant Positive := Positive
                          (((Operation.Source_Y + Y) * Object.Pixel_Width
                            + Operation.Source_X + X) * 4 + 1);
                        DI : constant Positive := Positive
                          (((Operation.Target_Y + Y) * Object.Pixel_Width
                            + Operation.Target_X + X) * 4 + 1);
                     begin
                        Composite_Pixel
                          (Canvas_B.all,
                           DI,
                           Natural (Canvas_A (SI)),
                           Natural (Canvas_A (SI + 1)),
                           Natural (Canvas_A (SI + 2)),
                           Natural (Canvas_A (SI + 3)),
                           Operation.Composition_Mode);
                     end;
                  end loop;
               end loop;
               if Target_Data'Length /= Canvas_Length then
                  Free_Image_Data (Canvas_A);
                  Free_Image_Data (Canvas_B);
                  Release_Archived_Frames;
                  return False;
               end if;
               Target_Data.all := Canvas_B.all;
            end if;
         end;
      else
         declare
            Target_Data : constant RM.Image_Data_Access :=
              Target_Bytes
                (Operation.Target_Frame,
                 Operation.Archived_Frames,
                 Create => Operation.New_Frame);
            Bytes_Per_Pixel : constant Natural :=
              (if Operation.Raw_Format = 8 then 1
               elsif Operation.Raw_Format = 16 then 2
               elsif Operation.Raw_Format in 24 | 32
               then Operation.Raw_Format / 8
               else 0);
         begin
            if Target_Data /= null then
               if Operation.New_Frame then
                  if Operation.Base_Frame > 0
                    and then
                      (if Operation.Archived_Frames
                       then Target_Bytes
                         (Positive (Operation.Base_Frame), True) /= null
                       else Animation_Frame_Exists
                         (Object, Operation.Base_Frame))
                  then
                     Copy_Replay_Frame_To_RGBA
                       (Positive (Operation.Base_Frame),
                        Operation.Archived_Frames,
                        Canvas_A.all,
                        Valid);
                     if not Valid then
                        Free_Image_Data (Canvas_A);
                        Free_Image_Data (Canvas_B);
                        Release_Archived_Frames;
                        return False;
                     end if;
                  else
                     Fill_Background
                       (Canvas_A.all, Operation.Background_Color);
                  end if;
               else
                  Copy_Replay_Frame_To_RGBA
                    (Operation.Target_Frame,
                     Operation.Archived_Frames,
                     Canvas_A.all,
                     Valid);
                  if not Valid then
                     Free_Image_Data (Canvas_A);
                     Free_Image_Data (Canvas_B);
                     Release_Archived_Frames;
                     return False;
                  end if;
               end if;
               if Bytes_Per_Pixel = 0
                 or else Operation.Bytes = null
                 or else Operation.Target_X > Object.Pixel_Width
                 or else Operation.Target_Y > Object.Pixel_Height
                 or else Operation.Data_Width >
                   Object.Pixel_Width - Operation.Target_X
                 or else Operation.Data_Height >
                   Object.Pixel_Height - Operation.Target_Y
               then
                  Free_Image_Data (Canvas_A);
                  Free_Image_Data (Canvas_B);
                  Release_Archived_Frames;
                  return False;
               end if;
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
                           then Kitty_Indexed_Color
                             (R, Natural (Operation.Bytes (SI)))
                           else (0.0, 0.0, 0.0, 1.0));
                        SR : constant Natural :=
                          (if Operation.Raw_Format in 8 | 16
                           then Natural (Color_Byte (Palette.R))
                           else Natural (Operation.Bytes (SI)));
                        SG : constant Natural :=
                          (if Operation.Raw_Format in 8 | 16
                           then Natural (Color_Byte (Palette.G))
                           else Natural (Operation.Bytes (SI + 1)));
                        SB : constant Natural :=
                          (if Operation.Raw_Format in 8 | 16
                           then Natural (Color_Byte (Palette.B))
                           else Natural (Operation.Bytes (SI + 2)));
                        SA : constant Natural :=
                          (if Operation.Raw_Format = 16
                           then Natural (Operation.Bytes (SI + 1))
                           elsif Operation.Raw_Format = 32
                           then Natural (Operation.Bytes (SI + 3))
                           else 255);
                     begin
                        Composite_Pixel
                          (Canvas_A.all,
                           DI,
                           SR,
                           SG,
                           SB,
                           SA,
                           Operation.Composition_Mode);
                     end;
                  end loop;
               end loop;
               if Target_Data'Length /= Canvas_Length then
                  Free_Image_Data (Canvas_A);
                  Free_Image_Data (Canvas_B);
                  Release_Archived_Frames;
                  return False;
               end if;
               Target_Data.all := Canvas_A.all;
            end if;
         end;
      end if;
      Operation := Terminal.App.Image_Store.Next_Theme_Operation (Operation);
   end loop;
   --  Replay uses private working copies.  Publish them only after every
   --  operation has succeeded, so a failed recolor cannot partially mutate
   --  store-owned image memory.
   declare
      Current : Archived_Frame_State_Access := Archived_Frames;
   begin
      while Current /= null loop
         if Current.Number = 1 then
            Terminal.App.Image_Store.Replace_Root_RGBA
              (R.Image_Objects, Object, Current.Bytes,
               Preserve_Indexed => True);
         elsif Animation_Frame_Exists (Object, Current.Number) then
            Terminal.App.Image_Store.Replace_Frame_Data
              (R.Image_Objects, Object, Current.Number, Current.Bytes);
         end if;
         --  Frames retained only as dependencies of later operations are
         --  deliberately not republished after they have been deleted from
         --  the live animation.
         Current := Current.Next;
      end loop;
   end;
   Free_Image_Data (Canvas_A);
   Free_Image_Data (Canvas_B);
   Release_Archived_Frames;
   return True;
exception
   when Storage_Error =>
      Free_Image_Data (Canvas_A);
      Free_Image_Data (Canvas_B);
      Release_Archived_Frames;
      return False;
   when others =>
      Free_Image_Data (Canvas_A);
      Free_Image_Data (Canvas_B);
      Release_Archived_Frames;
      raise;
end Replay_Theme_Operations;
