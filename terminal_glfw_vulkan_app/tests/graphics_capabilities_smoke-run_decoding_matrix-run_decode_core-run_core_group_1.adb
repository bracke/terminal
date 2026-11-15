separate (Graphics_Capabilities_Smoke.Run_Decoding_Matrix.Run_Decode_Core)
procedure Run_Core_Group_1 is
begin
      Reset_And_Initialize_Fixtures;
      declare
         Too_Long : Graphics.Graphics_Data_Preview :=
           Graphics.Data_Preview_Text
             (Terminal.Core.Kitty_Graphics,
              "Gf=32,s=1,v=1;/wAA//8=");
         Too_Short : Graphics.Graphics_Data_Preview :=
           Graphics.Data_Preview_Text
             (Terminal.Core.Kitty_Graphics,
              "Gf=32,s=1,v=1;/wAA");
      begin
         Assert
           (not Too_Long.Decode_Complete
            and then Too_Long.Decode_Status = Graphics.Decode_Trailing_Data
            and then Too_Long.Decoded_Length = 4,
            "raw Kitty decode rejects bytes beyond the exact image extent");
         Assert
           (not Too_Short.Decode_Complete
            and then Too_Short.Decode_Status = Graphics.Decode_Invalid_Data
            and then Too_Short.Decoded_Length = 3,
            "raw Kitty decode rejects data shorter than the exact image extent");
         Graphics.Release (Too_Long);
         Graphics.Release (Too_Short);
      end;
      declare
         JPEG_Base64 : constant String :=
           Base64_Encode (JPEG_Storage, JPEG_Length);
      begin
         --  The private formats f=1001 and f=1002 carry JPEG and GIF files,
         --  and only those.
         declare
            GIF_Base64 : constant String :=
              "R0lGODlhAQABAPAAAP8AAAAAACH5BAAFAAAALAAAAAABAAEAAAICRAEAIfkEAAcA"
              & "AAAsAAAAAAEAAQCAAAD/AAAAAgJEAQA7";
            Private_JPEG : Graphics.Graphics_Data_Preview :=
              Graphics.Data_Preview_Text
                (Terminal.Core.Kitty_Graphics, "Gf=1001,a=T,c=1,r=1;" & JPEG_Base64);
            Private_GIF : Graphics.Graphics_Data_Preview :=
              Graphics.Data_Preview_Text
                (Terminal.Core.Kitty_Graphics, "Gf=1002,a=T,c=1,r=1;" & GIF_Base64);
            Mislabelled : Graphics.Graphics_Data_Preview :=
              Graphics.Data_Preview_Text
                (Terminal.Core.Kitty_Graphics, "Gf=1002,a=T,c=1,r=1;" & JPEG_Base64);
            Private_JPEG_Header : constant Graphics.Graphics_Header :=
              Graphics.Header_Text
                (Terminal.Core.Kitty_Graphics,
                 "Gf=1001,a=T,c=1,r=1;" & JPEG_Base64);
            Private_GIF_Header : constant Graphics.Graphics_Header :=
              Graphics.Header_Text
                (Terminal.Core.Kitty_Graphics,
                 "Gf=1002,a=T,c=1,r=1;" & GIF_Base64);
         begin
            Assert
              (Private_JPEG_Header.Recognized
               and then Private_JPEG_Header.Kitty_Control_Data_Valid,
               "Kitty f=1001 passes control validation");
            Assert
              (Private_GIF_Header.Recognized
               and then Private_GIF_Header.Kitty_Control_Data_Valid,
               "Kitty f=1002 passes control validation");
            Assert
              (Private_JPEG.Decode_Complete
               and then Private_JPEG.Raw_Format = 32
               and then Private_JPEG.Pixel_Width = 1
               and then Private_JPEG.Pixel_Height = 1,
               "Kitty f=1001 decodes JPEG");
            Assert
              (Private_GIF.Decode_Complete
               and then Private_GIF.Raw_Format = 32
               and then Private_GIF.Pixel_Width = 1
               and then Private_GIF.Pixel_Height = 1,
               "Kitty f=1002 decodes GIF");
            Assert
              (not Mislabelled.Decode_Complete
               and then Mislabelled.Decode_Status = Graphics.Decode_Unsupported_Format,
               "Kitty f=1002 rejects a JPEG");
            Assert_Storage_Invariant (Private_JPEG, "Kitty JPEG");
            Assert_Storage_Invariant (Private_GIF, "Kitty GIF");
            Assert_Storage_Invariant (Mislabelled, "mislabelled Kitty GIF");
            declare
               JPEG_Input : Terminal.Common.Bytes.Byte_Array (1 .. JPEG_Length);
               Invalid_JPEG : constant Terminal.Common.Bytes.Byte_Array :=
                 (1 => 0);
            begin
               for I in JPEG_Input'Range loop
                  JPEG_Input (I) := Terminal.Common.Bytes.Byte (JPEG_Storage (I));
               end loop;
               Media_Decoding.Decode_JPEG_RGBA_Data
                 (JPEG_Input,
                  JPEG_Input'Length,
                  Private_JPEG,
                  Maximum_Decoded_Bytes => 4,
                  Maximum_Pixel_Dimension => 1);
               Assert
                 (Private_JPEG.Decode_Complete
                  and then Private_JPEG.Decoded_Length = 4
                  and then Graphics.Has_Bytes (Private_JPEG),
                  "JPEG output quota does not also cap decoder workspace");
               Media_Decoding.Decode_JPEG_RGBA_Data
                 (Invalid_JPEG, Invalid_JPEG'Length, Private_JPEG);
               Assert
                 (Private_JPEG.Raw_Format = 0
                  and then Private_JPEG.Pixel_Width = 0
                  and then Private_JPEG.Pixel_Height = 0
                  and then Private_JPEG.Decoded_Row_Stride_Bytes = 0
                  and then Private_JPEG.Decoded_Length = 0
                  and then not Graphics.Has_Bytes (Private_JPEG)
                  and then not Private_JPEG.Decode_Complete,
                  "failed JPEG reuse does not publish stale pixels");
               Media_Decoding.Decode_JPEG_RGBA_Data
                 (JPEG_Input, JPEG_Input'Length + 1, Private_JPEG);
               Assert
                 (Private_JPEG.Decode_Status = Graphics.Decode_Invalid_Data
                  and then not Private_JPEG.Decode_Complete
                  and then not Graphics.Has_Bytes (Private_JPEG),
                  "decoder boundary rejects a length beyond its input view");
               declare
                  Hidden : Terminal.App.Owned_Image_Data.Owner;
               begin
                  Graphics.Take_Bytes (Private_JPEG, Hidden);
                  Assert
                    (Terminal.App.Owned_Image_Data.Is_Empty (Hidden),
                     "failed JPEG reuse cannot detach unpublished capacity");
               end;
            end;
            Graphics.Release (Private_JPEG);
            Graphics.Release (Private_GIF);
            Graphics.Release (Mislabelled);
         end;
      end;
      Kitty_Header := Graphics.Header (Kitty);
      Assert (Kitty_Header.Recognized, "kitty header recognized");
      Assert (Kitty_Header.Has_Data, "kitty header data marker");
      Assert (Kitty_Header.Kitty_Action = 'T', "kitty action field");
      Assert (Kitty_Header.Kitty_ID = 42, "kitty image id field");
      Assert (Kitty_Header.Kitty_Format = 32, "kitty format field");
      Assert
        (Graphics.Header (Kitty_RGBA).Kitty_Action = 't',
         "kitty omitted action defaults to transmit-only");
      Kitty_Placement_Header := Graphics.Header_Text
        (Terminal.Core.Kitty_Graphics,
         "Ga=p,i=42,I=43,p=44,t=d,o=z,q=1,N=1,S=45,O=46," &
         "x=2,y=3,w=4,h=5,X=6,Y=7,z=-8,C=1,U=1,P=9,Q=10," &
         "H=-11,V=12,d=p");
      Assert
        (Kitty_Placement_Header.Recognized
         and then Kitty_Placement_Header.Kitty_Action = 'p'
         and then Kitty_Placement_Header.Kitty_ID = 42
         and then Kitty_Placement_Header.Kitty_Image_Number = 43
         and then Kitty_Placement_Header.Kitty_Placement_ID = 44,
         "kitty placement identity fields");
      Assert
        (Kitty_Placement_Header.Kitty_Transmission = 'd'
         and then Kitty_Placement_Header.Kitty_Compression = 'z'
         and then Kitty_Placement_Header.Kitty_Delete = 'p'
         and then Kitty_Placement_Header.Kitty_Quiet = 1
         and then Kitty_Placement_Header.Kitty_Usage_Hint = 1
         and then Kitty_Placement_Header.Kitty_Data_Size = 45
         and then Kitty_Placement_Header.Kitty_Data_Offset = 46,
         "kitty control fields");
      Assert
        (Kitty_Placement_Header.Kitty_Source_X = 2
         and then Kitty_Placement_Header.Kitty_Source_Y = 3
         and then Kitty_Placement_Header.Kitty_Source_Width = 4
         and then Kitty_Placement_Header.Kitty_Source_Height = 5
         and then Kitty_Placement_Header.Kitty_Cell_X = 6
         and then Kitty_Placement_Header.Kitty_Cell_Y = 7,
         "kitty crop and cell offset fields");
      Assert
        (Kitty_Placement_Header.Kitty_Z_Index = -8
         and then Kitty_Placement_Header.Kitty_No_Cursor_Move
         and then Kitty_Placement_Header.Kitty_Virtual_Placement,
         "kitty placement behavior fields");
      Assert
        (Kitty_Placement_Header.Kitty_Parent_ID = 9
         and then Kitty_Placement_Header.Kitty_Parent_Placement_ID = 10
         and then Kitty_Placement_Header.Kitty_Parent_Offset_X = -11
         and then Kitty_Placement_Header.Kitty_Parent_Offset_Y = 12,
         "kitty relative placement fields");
      declare
         Max_ID_Header : constant Graphics.Graphics_Header :=
           Graphics.Header_Text
             (Terminal.Core.Kitty_Graphics,
              "Gi=4294967295,p=4294967295");
      begin
         Assert
           (Max_ID_Header.Kitty_ID = Terminal.Core.Graphics_ID'Last
            and then Max_ID_Header.Kitty_Placement_ID =
              Terminal.Core.Graphics_ID'Last,
            "kitty IDs should preserve all unsigned 32 bits");
      end;end Run_Core_Group_1;
