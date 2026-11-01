separate (Renderer_Metrics_Smoke)
procedure Run_Protocol_Transactions is
begin
   declare
      Chunk_T : Terminal.Core.Terminal;
      Chunk_Init : Terminal.Core.Initialize_Status;
      Chunk_Feed : Terminal.Core.Feed_Status;
      Event : Terminal.Core.Graphics_Event;
      Result : Terminal.Core.Kitty_Graphics_Result;
      Tabs : Terminal.App.Tabs.Tab_State;
      Splits : Terminal.App.Splits.Split_State;
      Objects_Before : constant Natural :=
        Terminal.App.Renderer.Diagnostics (R).Kitty_Image_Object_Count;

      procedure Feed_Render
        (Text : String;
         Expected : Terminal.Core.Kitty_Graphics_Result_Code;
         Message : String)
      is
         --  Keep each protocol exchange isolated for source-level failure
         --  diagnostics.
         Snapshots : Terminal.App.Renderer.Snapshot_Array (1 .. 1);
      begin
         Terminal.Core.Feed
           (Chunk_T,
            To_Bytes (ASCII.ESC & "_" & Text & ASCII.ESC & "\"),
            Chunk_Feed);
         Assert (Chunk_Feed = Terminal.Core.Ok, Message & " feed");
         Terminal.Core.Peek_Graphics_Event (Chunk_T, Event);
         if not Event.Pending then
            Assert
              (Expected = Terminal.Core.Kitty_No_Response,
               Message & " incomplete transaction result");
            return;
         end if;
         Terminal.Core.Snapshot (Chunk_T, Snapshots (1));
         Snapshots (1).Graphics := Event;
         Terminal.App.Renderer.Layout.Render_App
           (R,
            Snapshots,
            1,
            Terminal.App.Tabs.Snapshot (Tabs),
            Terminal.App.Splits.Snapshot (Splits),
            Render_Status);
         Terminal.Core.Release (Snapshots (1));
         Assert (Render_Status = Terminal.App.Renderer.Ok, Message & " render");
         Result := Terminal.App.Renderer.Graphics.Result (R, Event);
         Assert (Result.Code = Expected, Message & " protocol result");
         Terminal.Core.Complete_Graphics_Event (Chunk_T, Event, Result);
         Terminal.App.Renderer.Graphics.Commit_Visible_Events (R);
      end Feed_Render;
   begin
      Terminal.Core.Initialize (Chunk_T, 2, 4, 10, Chunk_Init);
      Assert (Chunk_Init = Terminal.Core.Ok, "chunk validation initialize");
      Terminal.Core.Set_Graphics_Stream_ID (Chunk_T, 3_001);
      Terminal.App.Tabs.Initialize (Tabs);
      Terminal.App.Splits.Initialize (Splits);

      Feed_Render
        ("Gq=2,a=t,i=90,f=32,s=1,v=1,m=1;AAA",
         Terminal.Core.Kitty_EINVAL,
         "non-final chunk alignment rejection");
      Feed_Render
        ("Gq=2,a=t,i=91,f=32,s=1,v=1,m=1;"
         & Repeat_Char ('A', 4_097),
         Terminal.Core.Kitty_EINVAL,
         "oversized chunk rejection");
      Feed_Render
        ("Gq=2,a=t,i=91,f=32,s=1,v=1,m=2;AAAA",
         Terminal.Core.Kitty_EINVAL,
         "invalid chunk flag rejection");

      Feed_Render
        ("Gq=2,a=t,i=92,f=32,s=1,v=1,m=1;AAAA",
         Terminal.Core.Kitty_No_Response,
         "valid first chunk retention");
      Feed_Render
        ("Gm=0,i=92;AA==",
         Terminal.Core.Kitty_EINVAL,
         "continuation control rejection");

      Feed_Render
        ("Gq=2,a=t,i=94,f=32,s=1,v=1,m=1;/wAA",
         Terminal.Core.Kitty_No_Response,
         "delete-cancel first chunk retention");
      Feed_Render
        ("Gq=2,a=d,d=i,i=94",
         Terminal.Core.Kitty_OK,
         "delete command aborts partial upload");
      Feed_Render
        ("Gq=2,a=t,i=94,f=32,s=1,v=1,m=1;/wAA",
         Terminal.Core.Kitty_No_Response,
         "fresh chunk after delete cancellation");
      Feed_Render
        ("Gq=2,m=0;/w==",
         Terminal.Core.Kitty_OK,
         "completed chunk after delete cancellation");

      Feed_Render
        ("Gq=2,a=t,i=92,f=32,s=1,v=1;/wAA/w==",
         Terminal.Core.Kitty_OK,
         "post-rejection transaction recovery");
      Assert
        (Terminal.App.Renderer.Diagnostics (R).Kitty_Image_Object_Count =
           Objects_Before + 2,
         "valid transfer succeeds after malformed chunks");

      Feed_Render
        ("Gq=2,a=t,i=180,i=181,f=32,s=1,v=1;/wAA/w==",
         Terminal.Core.Kitty_EINVAL,
         "duplicate control rejection");
      Feed_Render
        ("Gq=2,a=t,i=182,f=32,s=bad,v=1;/wAA/w==",
         Terminal.Core.Kitty_EINVAL,
         "malformed numeric control rejection");
      Feed_Render
        ("Gq=2,a=p,i=92;AAAA",
         Terminal.Core.Kitty_EINVAL,
         "put action payload rejection");
      Feed_Render
        ("Gq=2,a=t,i=183,f=32,s=1,v=1",
         Terminal.Core.Kitty_EINVAL,
         "transmit action missing payload rejection");
      Feed_Render
        ("Gq=2,a=x,i=184",
         Terminal.Core.Kitty_ENOTSUP,
         "unsupported action rejection");

      Feed_Render
        ("Ga=q,i=200,f=32,s=1,v=1;/wAA/w==",
         Terminal.Core.Kitty_OK,
         "query validates direct raw payload");
      Feed_Render
        ("Ga=q,i=201,f=32,s=1,v=1;%%%%",
         Terminal.Core.Kitty_EINVAL,
         "query rejects invalid direct payload");
      Feed_Render
        ("Ga=q,i=202,f=32,s=1,v=1,o=z;eJz7z8DwHwAE/wH/",
         Terminal.Core.Kitty_OK,
         "query validates compressed direct payload");
      Feed_Render
        ("Ga=q,i=204,f=100,o=z;"
         & "eJzrDPBz5+WS4mJgYOD19HAJAtKMIMzBBCQnlAff"
         & "A0u4OIZUzEn+cf4AAwMzIyPDSYZjUx4BJRg8Xf1c1jklNAEA1dYQSw==",
         Terminal.Core.Kitty_EINVAL,
         "direct compressed PNG query requires inflated size");
      Feed_Render
        ("Ga=q,i=203,f=32,s=1,v=1,t=x;/wAA/w==",
         Terminal.Core.Kitty_ENOTSUP,
         "query rejects unsupported transfer medium");
      Assert
        (Terminal.App.Renderer.Diagnostics (R).Kitty_Image_Object_Count =
           Objects_Before + 2,
         "query validation must not retain image objects");

      Feed_Render
        ("Gq=2,a=T,i=95,f=32,s=1,v=1,c=1,r=1,C=1,o=z;"
         & "eJz7z8DwHwAE/wH/",
         Terminal.Core.Kitty_OK,
         "zlib raw direct transfer");
      Feed_Render
        ("Gq=2,a=T,i=96,f=100,S=70,c=1,r=1,C=1,o=z;"
         & "eJzrDPBz5+WS4mJgYOD19HAJAtKMIMzBBCQnlAff"
         & "A0u4OIZUzEn+cf4AAwMzIyPDSYZjUx4BJRg8Xf1c1jklNAEA1dYQSw==",
         Terminal.Core.Kitty_OK,
         "zlib PNG direct transfer");
      Feed_Render
        ("Gq=2,a=T,i=97,f=32,s=1,v=1,c=1,r=1,C=1,o=z,m=1;"
         & "eJz7z8Dw",
         Terminal.Core.Kitty_No_Response,
         "zlib raw first chunk");
      Feed_Render
        ("Gq=2,m=0;HwAE/wH/",
         Terminal.Core.Kitty_OK,
         "zlib raw final chunk");
      Feed_Render
        ("Gq=2,a=T,i=98,f=32,s=1,v=1,c=1,r=1,C=1,o=z;"
         & "eJz7z8DwHwAE/wHA",
         Terminal.Core.Kitty_EINVAL,
         "zlib checksum rejection");
      Feed_Render
        ("Gq=2,a=T,i=99,f=100,c=1,r=1,C=1,o=z;"
         & "eJzrDPBz5+WS4mJgYOD19HAJAtKMIMzBBCQnlAff"
         & "A0u4OIZUzEn+cf4AAwMzIyPDSYZjUx4BJRg8Xf1c1jklNAEA1dYQSw==",
         Terminal.Core.Kitty_EINVAL,
         "zlib PNG size requirement");
      Assert
        (Terminal.App.Renderer.Diagnostics (R).Kitty_Image_Object_Count =
           Objects_Before + 5,
         "zlib transfers install only validated image objects");
      Feed_Render
        ("Gq=2,a=T,f=32,s=1,v=1,c=1,r=1,C=1,o=z;"
         & "eJz7z8DwHwAE/wH/",
         Terminal.Core.Kitty_OK,
         "anonymous zlib raw display");
      Assert
        (Terminal.App.Renderer.Diagnostics (R).Kitty_Image_Object_Count =
           Objects_Before + 6,
         "anonymous zlib display retains an anonymous image object");

      Feed_Render
        ("Gq=2,a=t,i=110,f=32,s=2,v=1;/wAA/wD/AP8=",
         Terminal.Core.Kitty_OK,
         "geometry source transmission");
      Feed_Render
        ("Gq=2,a=p,i=110,p=10,C=1",
         Terminal.Core.Kitty_OK,
         "natural geometry placement");
      Feed_Render
        ("Gq=2,a=p,i=110,p=11,c=2,C=1",
         Terminal.Core.Kitty_OK,
         "one-sided geometry placement");
      Feed_Render
        ("Gq=2,a=p,i=110,p=12,c=2,r=2,C=1",
         Terminal.Core.Kitty_OK,
         "letterboxed geometry placement");
      Feed_Render
        ("Gq=2,a=p,i=110,p=13,c=0,C=1",
         Terminal.Core.Kitty_EINVAL,
         "zero column geometry rejection");
      Feed_Render
        ("Gq=2,a=p,i=110,p=14,x=2,C=1",
         Terminal.Core.Kitty_EINVAL,
         "empty source crop rejection");
      Feed_Render
        ("Gq=2,a=p,i=110,p=15,X="
         & Trimmed_Natural (Terminal.App.Renderer.Cell_Width (R))
         & ",C=1",
         Terminal.Core.Kitty_EINVAL,
         "out-of-cell x offset rejection");
      Feed_Render
        ("Gq=2,a=p,i=110,p=16,x=bad,C=1",
         Terminal.Core.Kitty_EINVAL,
         "malformed crop rejection");
      declare
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Testing.Last_Frame (R);
         Natural_Count : Natural := 0;
         Scaled_Count : Natural := 0;
         Scaled_Min_Y : Float := Float'Last;
         Scaled_Max_Y : Float := Float'First;
         Expected_Scaled_Width : constant Float :=
           Float (2 * Terminal.App.Renderer.Cell_Width (R));
         Expected_Scaled_Height : constant Float :=
           Float (Terminal.App.Renderer.Cell_Width (R));
      begin
         for I in 1 .. Frame.Image_Count loop
            if Frame.Images (I).Image_ID = 110 then
               if Frame.Images (I).Width = 2.0
                 and then Frame.Images (I).Height = 1.0
               then
                  Natural_Count := Natural_Count + 1;
               elsif Frame.Images (I).Width = Expected_Scaled_Width
                 and then Frame.Images (I).Height = Expected_Scaled_Height
               then
                  Scaled_Count := Scaled_Count + 1;
                  Scaled_Min_Y := Float'Min
                    (Scaled_Min_Y, Frame.Images (I).Y);
                  Scaled_Max_Y := Float'Max
                    (Scaled_Max_Y, Frame.Images (I).Y);
               end if;
            end if;
         end loop;
         Assert
           (Natural_Count = 1 and then Scaled_Count = 2,
            "placement geometry preserves natural size and aspect ratio");
         Assert
           (Scaled_Max_Y > Scaled_Min_Y,
            "two-axis placement centers letterboxed image content");
      end;
      Feed_Render
        ("Gq=2,a=T,f=32,s=2,v=1,C=1;/wAA/wD/AP8=",
         Terminal.Core.Kitty_OK,
         "anonymous natural geometry display");
      declare
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Testing.Last_Frame (R);
         Found : Boolean := False;
      begin
         for I in 1 .. Frame.Image_Count loop
            if Frame.Images (I).Protocol =
              Terminal.App.Render_Model.Image_Kitty
              and then Frame.Images (I).Image_ID = 0
              and then Frame.Images (I).Width = 2.0
              and then Frame.Images (I).Height = 1.0
            then
               Found := True;
            end if;
         end loop;
         Assert
           (Found,
            "anonymous placement derives natural geometry without an ID");
      end;

      Terminal.App.Renderer.Graphics.Release_Stream (R, 3_001);
      Assert
        (Terminal.App.Renderer.Diagnostics (R).Kitty_Image_Object_Count =
           Objects_Before,
         "chunk validation stream cleanup");
      Terminal.Core.Finalize (Chunk_T);
   end;

   declare
      Quota_R : Terminal.App.Renderer.Renderer;
      Quota_Status : Terminal.App.Renderer.Init_Status;
      Quota_T : Terminal.Core.Terminal;
      Quota_Init : Terminal.Core.Initialize_Status;
      Quota_Feed : Terminal.Core.Feed_Status;
      Event : Terminal.Core.Graphics_Event;
      Result : Terminal.Core.Kitty_Graphics_Result;
      Tabs : Terminal.App.Tabs.Tab_State;
      Splits : Terminal.App.Splits.Split_State;

      procedure Feed_Quota
        (Text : String;
         Expected : Terminal.Core.Kitty_Graphics_Result_Code;
         Message : String)
      is
         Snapshots : Terminal.App.Renderer.Snapshot_Array (1 .. 1);
         Local_Render_Status : Terminal.App.Renderer.Render_Status;
      begin
         Terminal.Core.Feed
           (Quota_T,
            To_Bytes (ASCII.ESC & "_" & Text & ASCII.ESC & "\"),
            Quota_Feed);
         Assert (Quota_Feed = Terminal.Core.Ok, Message & " feed");
         Terminal.Core.Peek_Graphics_Event (Quota_T, Event);
         Terminal.Core.Snapshot (Quota_T, Snapshots (1));
         Snapshots (1).Graphics := Event;
         Terminal.App.Renderer.Layout.Render_App
           (Quota_R,
            Snapshots,
            1,
            Terminal.App.Tabs.Snapshot (Tabs),
            Terminal.App.Splits.Snapshot (Splits),
            Local_Render_Status);
         Terminal.Core.Release (Snapshots (1));
         Assert
           (Local_Render_Status = Terminal.App.Renderer.Ok,
            Message & " render");
         Result := Terminal.App.Renderer.Graphics.Result (Quota_R, Event);
         Assert (Result.Code = Expected, Message & " result");
         Terminal.Core.Complete_Graphics_Event (Quota_T, Event, Result);
         Terminal.App.Renderer.Graphics.Commit_Visible_Events (Quota_R);
      end Feed_Quota;
   begin
      Terminal.App.Renderer.Initialize_Headless (Quota_R, Quota_Status);
      Assert (Quota_Status = Terminal.App.Renderer.Ok, "quota renderer init");
      Terminal.App.Renderer.Graphics.Set_Resource_Limits
        (Quota_R,
         (Image_Objects => 2,
          Image_Bytes   => 8,
          Placements    => 2,
          Animation_Frames => 2,
          others => <>));
      Assert
        (Terminal.App.Renderer.Graphics.Resource_Limits (Quota_R) =
           (Image_Objects => 2,
            Image_Bytes => 8,
            Placements => 2,
            Animation_Frames => 2,
            others => <>),
         "configurable graphics quotas");
      Terminal.Core.Initialize (Quota_T, 2, 4, 10, Quota_Init);
      Assert (Quota_Init = Terminal.Core.Ok, "quota core init");
      Terminal.Core.Set_Graphics_Stream_ID (Quota_T, 3_002);
      Terminal.App.Tabs.Initialize (Tabs);
      Terminal.App.Splits.Initialize (Splits);

      Feed_Quota
        ("Gq=2,a=t,i=1,N=0,f=32,s=1,v=1;/wAA/w==",
         Terminal.Core.Kitty_OK,
         "quota first image");
      Feed_Quota
        ("Gq=2,a=t,i=2,N=1,f=32,s=1,v=1;AP8A/w==",
         Terminal.Core.Kitty_OK,
         "quota transient image");
      Feed_Quota
        ("Gq=2,a=t,i=3,N=0,f=32,s=1,v=1;AAD//w==",
         Terminal.Core.Kitty_OK,
         "quota eviction image");
      Assert
        (Terminal.App.Renderer.Diagnostics (Quota_R).Kitty_Image_Object_Count = 2
         and then
           Terminal.App.Renderer.Diagnostics (Quota_R).Kitty_Image_Object_Bytes = 8,
         "quota accounting after eviction");
      Feed_Quota
        ("Gq=2,a=p,i=2,p=1,c=1,r=1,C=1",
         Terminal.Core.Kitty_ENOENT,
         "transient image evicted first");
      Feed_Quota
        ("Gq=2,a=p,i=1,p=1,c=1,r=1,C=1",
         Terminal.Core.Kitty_OK,
         "older persistent-hint image retained");
      Feed_Quota
        ("Gq=2,a=p,i=3,p=1,c=1,r=1,C=1",
         Terminal.Core.Kitty_OK,
         "new image retained");
      Feed_Quota
        ("Gq=2,a=t,i=4,N=0,f=32,s=1,v=1;/////w==",
         Terminal.Core.Kitty_ENOMEM,
         "image quota response when all objects are placed");
      Feed_Quota
        ("Gq=2,a=p,i=1,p=2,c=1,r=1,C=1",
         Terminal.Core.Kitty_ENOMEM,
         "placement quota response");

      Terminal.App.Renderer.Graphics.Release_Stream (Quota_R, 3_002);
      Terminal.Core.Finalize (Quota_T);
      Terminal.App.Renderer.Finalize (Quota_R);
   end;

   Terminal.App.Renderer.Graphics.Release_Stream (R, 4_101);
   Terminal.Core.Set_Graphics_Stream_ID (T, 4_102);

   declare
      Segment_Count : constant Natural := 64;
   begin
      for I in 1 .. Segment_Count loop
         declare
            Prefix : constant String :=
              (if I = 1 then "Gf=32,a=T,C=1,s=48,v=1,c=12,r=1,m=1;"
               elsif I = Segment_Count then "Gm=0;"
               else "Gm=1;");
         begin
            Terminal.Core.Feed
              (T,
               To_Bytes
                 (ASCII.ESC & "_" & Prefix & "AAAA" & ASCII.ESC & "\"),
               Feed_Status);
            Assert
              (Feed_Status = Terminal.Core.Ok,
               "many-segment kitty chunk feed failed");

            declare
               Snap : Terminal.Core.Render_Snapshot :=
                 Terminal.Core.Snapshot (T);
            begin
               Terminal.App.Renderer.Render (R, Snap, Render_Status);
               Terminal.Core.Release (Snap);
            end;
            Assert
              (Render_Status = Terminal.App.Renderer.Ok,
               "many-segment kitty chunk render failed");

            if I < Segment_Count then
               Assert
                 (Terminal.App.Renderer.Diagnostics (R).Last_Image_Count = 0,
                  "many-segment kitty chunk should wait for final segment");
            end if;
         end;
      end loop;

      declare
         Diagnostics : constant Terminal.App.Renderer.Renderer_Diagnostics :=
           Terminal.App.Renderer.Diagnostics (R);
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Testing.Last_Frame (R);
      begin
         Assert
           (Diagnostics.Last_Image_Raw_Format = 32
            and then Diagnostics.Last_Image_Pixel_Width = 48
            and then Diagnostics.Last_Image_Pixel_Height = 1,
            "many-segment kitty image diagnostic pixel metadata");
         Assert
           (Diagnostics.Last_Image_Encoded_Preview_Length = 0,
            "retained many-segment image no longer owns encoded chunks");
         Assert
           (not Diagnostics.Last_Image_Placeholder,
            "many-segment kitty image should be textured");
         Assert
           (Frame.Images (1).Decoded_Byte_Length = 48 * 4
            and then Frame.Images (1).Decoded_Bytes /= null
            and then Frame.Images (1).Decoded_Source =
              Terminal.App.Render_Model.Image_Decoded_Source_Buffer
            and then Frame.Images (1).Encoded_Source_Bytes = null,
            "many-segment kitty command should retain decoded pixels");
         Assert
           (not Frame.Images (1).Placeholder,
            "many-segment kitty command should be textured");
      end;
   end;

   Terminal.App.Renderer.Graphics.Release_Stream (R, 4_102);
   Terminal.Core.Initialize (T, 1, 1, 10, Core_Status);
   Assert
     (Core_Status = Terminal.Core.Ok,
      "large chunked raw core reinitialize failed");
   Terminal.Core.Set_Graphics_Stream_ID (T, 4_103);

   declare
      Width          : constant Natural := 450;
      Height         : constant Natural := 300;
      Decoded_Length : constant Natural := Width * Height * 4;
      Encoded_Length : constant Natural := Decoded_Length / 3 * 4;
      Chunk_Length   : constant Natural := 4_096;
      Sent           : Natural := 0;

      procedure Feed_Chunk
        (Text    : String;
         Message : String;
         Final   : Boolean)
      is
      begin
         Terminal.Core.Feed
           (T,
            To_Bytes (ASCII.ESC & "_" & Text & ASCII.ESC & "\"),
            Feed_Status);
         Assert (Feed_Status = Terminal.Core.Ok, Message & " feed failed");

         if Final then
            declare
               Event : Terminal.Core.Graphics_Event;
            begin
               Terminal.Core.Peek_Graphics_Event (T, Event);
               Terminal.App.Renderer.Graphics.Stage_Event
                 (R, Event, Terminal.Core.Graphics_Event_Payload (T, Event));
            end;
         end if;

         Render_And_Complete_Graphics (T);
         Assert (Render_Status = Terminal.App.Renderer.Ok, Message & " render failed");
         if not Final then
            Assert
              (Terminal.App.Renderer.Diagnostics (R).Last_Image_Count = 0,
               Message & " should wait for final chunk");
         end if;
      end Feed_Chunk;
   begin
      Feed_Chunk
        ("Gf=32,a=T,C=1,s=450,v=300,c=1,r=1,m=1;"
         & Repeat_Char ('A', Chunk_Length),
         "large chunked raw kitty first chunk",
         False);
      Sent := Sent + Chunk_Length;

      while Sent + Chunk_Length < Encoded_Length loop
         Feed_Chunk
           ("Gm=1;" & Repeat_Char ('A', Chunk_Length),
            "large chunked raw kitty middle chunk",
            False);
         Sent := Sent + Chunk_Length;
      end loop;

      Feed_Chunk
        ("Gm=0;" & Repeat_Char ('A', Encoded_Length - Sent),
         "large chunked raw kitty final chunk",
         True);

      declare
         Diagnostics : constant Terminal.App.Renderer.Renderer_Diagnostics :=
           Terminal.App.Renderer.Diagnostics (R);
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Testing.Last_Frame (R);
      begin
         Assert
           (Diagnostics.Last_Image_Raw_Format = 32
            and then Diagnostics.Last_Image_Pixel_Width = Width
            and then Diagnostics.Last_Image_Pixel_Height = Height,
            "large chunked raw kitty image diagnostic pixel metadata");
         Assert
           (Diagnostics.Last_Image_Decoded_Preview_Length =
            Terminal.App.Render_Model.Max_Image_Decoded_Preview_Length,
            "large chunked raw kitty decoded diagnostics preview length");
         Assert
           (Diagnostics.Last_Image_Payload_Preview_Complete,
            "large chunked raw kitty payload should be complete");
         Assert
           (not Diagnostics.Last_Image_Placeholder,
            "large chunked raw kitty image should be textured");
         Assert
           (Frame.Images (1).Pixel_Width = Width
            and then Frame.Images (1).Pixel_Height = Height
            and then Frame.Images (1).Decoded_Byte_Length = Decoded_Length
            and then Frame.Images (1).Decoded_Bytes /= null
            and then Frame.Images (1).Decoded_Source =
              Terminal.App.Render_Model.Image_Decoded_Source_Buffer
            and then Frame.Images (1).Encoded_Source_Bytes = null
            and then Frame.Images (1).Decoded_Preview_Length =
              Terminal.App.Render_Model.Max_Image_Decoded_Preview_Length,
            "large chunked raw kitty command should retain decoded pixels");
         Assert
           (not Frame.Images (1).Placeholder,
            "large chunked raw kitty command should be textured");
      end;
   end;

   Terminal.App.Renderer.Graphics.Release_Stream (R, 4_103);
   Terminal.Core.Set_Graphics_Stream_ID (T, 4_104);

   declare
      Payload : constant String :=
        "Gf=32,a=T,C=1,s=33,v=32,c=1,r=1;" & Repeat_Char ('A', 5632);
   begin
      Terminal.Core.Feed
        (T,
         To_Bytes (ASCII.ESC & "_" & Payload & ASCII.ESC & "\"),
         Feed_Status);
      Assert
        (Feed_Status = Terminal.Core.Ok,
         "large raw kitty graphics feed failed");
      Render_And_Complete_Graphics (T);
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "large raw graphics render failed");

      declare
         Diagnostics : constant Terminal.App.Renderer.Renderer_Diagnostics :=
           Terminal.App.Renderer.Diagnostics (R);
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Testing.Last_Frame (R);
      begin
         Assert
           (Diagnostics.Last_Image_Raw_Format = 32
            and then Diagnostics.Last_Image_Pixel_Width = 33
            and then Diagnostics.Last_Image_Pixel_Height = 32,
            "large raw graphics image diagnostic pixel metadata");
         Assert
           (Diagnostics.Last_Image_Decoded_Preview_Length =
            Terminal.App.Render_Model.Max_Image_Decoded_Preview_Length,
            "large raw graphics decoded preview length");
         Assert
           (Diagnostics.Last_Image_Payload_Preview_Complete,
            "large raw graphics payload should fit render buffer");
         Assert
           (not Diagnostics.Last_Image_Placeholder,
            "large raw graphics image should be textured");
         Assert
           (Frame.Images (1).Pixel_Width = 33
            and then Frame.Images (1).Pixel_Height = 32
            and then Frame.Images (1).Decoded_Byte_Length = 33 * 32 * 4
            and then Frame.Images (1).Decoded_Bytes /= null
            and then Frame.Images (1).Decoded_Source =
              Terminal.App.Render_Model.Image_Decoded_Source_Buffer
            and then Frame.Images (1).Encoded_Source_Bytes = null
            and then Frame.Images (1).Decoded_Preview_Length =
              Terminal.App.Render_Model.Max_Image_Decoded_Preview_Length,
            "large raw graphics command retained source metadata");
         Assert
           (not Frame.Images (1).Placeholder,
            "large raw graphics command should be textured");
      end;
   end;

   Terminal.App.Renderer.Graphics.Release_Stream (R, 4_104);
   Terminal.Core.Set_Graphics_Stream_ID (T, 4_105);

   declare
      Payload : constant String :=
        "Gf=32,a=T,C=1,s=129,v=128,c=1,r=1;" & Repeat_Char ('A', 88064);
   begin
      Terminal.Core.Feed
        (T,
         To_Bytes (ASCII.ESC & "_" & Payload & ASCII.ESC & "\"),
         Feed_Status);
      Assert
        (Feed_Status = Terminal.Core.Ok,
         "over-64KiB raw kitty graphics feed failed");
      Render_And_Complete_Graphics (T);
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "over-64KiB raw graphics render failed");

      declare
         Diagnostics : constant Terminal.App.Renderer.Renderer_Diagnostics :=
           Terminal.App.Renderer.Diagnostics (R);
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Testing.Last_Frame (R);
      begin
         Assert
           (Diagnostics.Last_Image_Raw_Format = 32
            and then Diagnostics.Last_Image_Pixel_Width = 129
            and then Diagnostics.Last_Image_Pixel_Height = 128,
            "over-64KiB raw graphics image diagnostic pixel metadata");
         Assert
           (Diagnostics.Last_Image_Decoded_Preview_Length =
            Terminal.App.Render_Model.Max_Image_Decoded_Preview_Length,
            "over-64KiB raw graphics decoded preview length");
         Assert
           (Diagnostics.Last_Image_Payload_Preview_Complete,
            "over-64KiB raw graphics payload should fit render buffer");
         Assert
           (not Diagnostics.Last_Image_Placeholder,
            "over-64KiB raw graphics image should be textured");
         Assert
           (Frame.Images (1).Pixel_Width = 129
            and then Frame.Images (1).Pixel_Height = 128
            and then Frame.Images (1).Decoded_Byte_Length = 129 * 128 * 4
            and then Frame.Images (1).Decoded_Bytes /= null
            and then Frame.Images (1).Decoded_Source =
              Terminal.App.Render_Model.Image_Decoded_Source_Buffer
            and then Frame.Images (1).Encoded_Source_Bytes = null
            and then Frame.Images (1).Decoded_Preview_Length =
              Terminal.App.Render_Model.Max_Image_Decoded_Preview_Length,
            "over-64KiB raw graphics command retained source metadata");
         Assert
           (not Frame.Images (1).Placeholder,
            "over-64KiB raw graphics command should be textured");
      end;
   end;

   Terminal.App.Renderer.Graphics.Release_Stream (R, 4_105);
   Terminal.Core.Set_Graphics_Stream_ID (T, 4_106);

   declare
      Payload : constant String :=
        "Gf=32,a=T,C=1,s=16385,v=1024,c=40,r=20;AAAA";
      Allocation_Failures_Before : constant Interfaces.Unsigned_64 :=
        Terminal.App.Renderer.Diagnostics (R).Allocation_Failure_Count;
   begin
      Terminal.Core.Feed
        (T,
         To_Bytes (ASCII.ESC & "_" & Payload & ASCII.ESC & "\"),
         Feed_Status);
      Assert
        (Feed_Status = Terminal.Core.Ok,
         "oversized raw kitty graphics feed failed");
      Render_And_Complete_Graphics (T);
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "oversized raw graphics render failed");

      declare
         Diagnostics : constant Terminal.App.Renderer.Renderer_Diagnostics :=
           Terminal.App.Renderer.Diagnostics (R);
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Testing.Last_Frame (R);
      begin
         Assert
           (Frame.Image_Count = 0
            and then Diagnostics.Allocation_Failure_Count =
              Allocation_Failures_Before + 1,
            "oversized raw graphics is rejected before image allocation");
      end;
   end;

   declare
      Payload : constant String :=
        "File=name=pixel.png;size=69;inline=1;doNotMoveCursor=1;width=20px;height=40px;"
        & "preserveAspectRatio=1:"
        & "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJAMaU4gAAAABJRU5ErkJggg==";
   begin
      Terminal.Core.Feed
        (T,
         To_Bytes (ASCII.ESC & "]1337;" & Payload & ASCII.BEL),
         Feed_Status);
      Assert (Feed_Status = Terminal.Core.Ok, "iTerm2 PNG image feed failed");
      Render_And_Complete_Graphics (T);
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "iTerm2 PNG image render failed");

      declare
         Diagnostics : constant Terminal.App.Renderer.Renderer_Diagnostics :=
           Terminal.App.Renderer.Diagnostics (R);
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Testing.Last_Frame (R);
      begin
         Assert
           (Diagnostics.Last_Image_Protocol =
            Terminal.App.Render_Model.Image_ITerm2,
            "iTerm2 PNG image diagnostic protocol");
         Assert
           (Diagnostics.Last_Image_Raw_Format = 32
            and then Diagnostics.Last_Image_Pixel_Width = 1
            and then Diagnostics.Last_Image_Pixel_Height = 1,
            "iTerm2 PNG image diagnostic pixel metadata");
         Assert
           (Diagnostics.Last_Image_Decoded_Preview_Length = 4,
            "iTerm2 PNG image decoded byte length");
         Assert
           (Diagnostics.Last_Image_Decoded_Preview_Bytes (1) = 16#FF#
            and then Diagnostics.Last_Image_Decoded_Preview_Bytes (2) = 16#00#
            and then Diagnostics.Last_Image_Decoded_Preview_Bytes (3) = 16#00#
            and then Diagnostics.Last_Image_Decoded_Preview_Bytes (4) = 16#FF#,
            "iTerm2 PNG image first RGBA pixel");
         Assert
           (not Diagnostics.Last_Image_Placeholder,
            "iTerm2 PNG image should be textured");
         Assert
           (Frame.Images (1).Protocol = Terminal.App.Render_Model.Image_ITerm2
            and then Frame.Images (1).Raw_Format = 32
            and then Frame.Images (1).Pixel_Width = 1
            and then Frame.Images (1).Pixel_Height = 1
            and then Frame.Images (1).Decoded_Row_Stride_Bytes = 4
            --  The 20x20 px box of a square image, clipped to the one-cell
            --  viewport, whose size comes from whatever font the host has.
            and then Frame.Images (1).Width =
              Float'Min (20.0, Float (Terminal.App.Renderer.Cell_Width (R)))
            and then Frame.Images (1).Height =
              Float'Min (20.0, Float (Terminal.App.Renderer.Cell_Height (R))),
            "iTerm2 PNG retained command is clipped to the viewport");
         Assert
           (Frame.Images (1).Decoded_Bytes /= null
            and then Frame.Images (1).Decoded_Source =
              Terminal.App.Render_Model.Image_Decoded_Source_Buffer
            and then Frame.Images (1).Encoded_Source_Bytes = null,
            "iTerm2 PNG retained command should borrow decoded pixels");
         Assert
           (not Frame.Images (1).Placeholder,
            "iTerm2 PNG image command should be textured");
      end;
   end;

   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "]1337;File=size=70;inline=1;doNotMoveCursor=1:"
         & "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJAMaU4gAAAABJRU5ErkJggg=="
         & ASCII.BEL),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "iTerm2 size mismatch feed");
   Render_And_Complete_Graphics (T);
   Assert
     (Render_Status = Terminal.App.Renderer.Ok
      and then Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count = 2,
      "iTerm2 declared size remains a non-binding progress hint");

   declare
      Cursor_T : Terminal.Core.Terminal;
      Cursor_Init : Terminal.Core.Initialize_Status;
      Cursor_Feed : Terminal.Core.Feed_Status;
      Event : Terminal.Core.Graphics_Event;
      Outcome : Terminal.Core.Kitty_Graphics_Result;
      Cursor_Tabs : Terminal.App.Tabs.Tab_State;
      Cursor_Splits : Terminal.App.Splits.Split_State;
   begin
      Terminal.Core.Initialize (Cursor_T, 4, 4, 10, Cursor_Init);
      Assert
        (Cursor_Init = Terminal.Core.Ok,
         "iTerm2 cursor renderer initialize");
      Terminal.Core.Set_Graphics_Stream_ID (Cursor_T, 4_107);
      Terminal.Core.Feed
        (Cursor_T,
         To_Bytes
           (ASCII.ESC
            & "]1337;File=inline=1;width=1;height=2;preserveAspectRatio=0:"
            & "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJAMaU4gAAAABJRU5ErkJggg=="
            & ASCII.BEL & "x"),
         Cursor_Feed);
      Assert (Cursor_Feed = Terminal.Core.Ok, "iTerm2 cursor renderer feed");
      Terminal.Core.Peek_Graphics_Event (Cursor_T, Event);
      Terminal.App.Tabs.Initialize (Cursor_Tabs);
      Terminal.App.Splits.Initialize (Cursor_Splits);
      declare
         Snaps : Terminal.App.Renderer.Snapshot_Array (1 .. 1);
      begin
         Terminal.Core.Snapshot (Cursor_T, Snaps (1));
         Terminal.App.Renderer.Layout.Render_App
           (R,
            Snaps,
            1,
            Terminal.App.Tabs.Snapshot (Cursor_Tabs),
            Terminal.App.Splits.Snapshot (Cursor_Splits),
            Render_Status);
         Terminal.Core.Release (Snaps (1));
      end;
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "iTerm2 cursor renderer render");
      Outcome := Terminal.App.Renderer.Graphics.Result (R, Event);
      Assert
        (Outcome.Code = Terminal.Core.Kitty_OK,
         "iTerm2 successful rendering produces an internal cursor commit result");
      Assert
        (Outcome.Move_Cursor and then Outcome.Cursor_To_Line_Start,
         "iTerm2 default rendering requests next-line cursor movement");
      Assert
        (Outcome.Placement_Rows = 2,
         "iTerm2 cursor movement reflects rendered cell height");
      Terminal.Core.Complete_Graphics_Event (Cursor_T, Event, Outcome);
      Terminal.App.Renderer.Graphics.Commit_Visible_Events (R);
      declare
         Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (Cursor_T);
      begin
         Assert
           (Terminal.Core.Cell_At (Snap, 3, 1).Text.Code_Point = 16#78#,
            "iTerm2 renderer commits cursor movement before trailing input");
         Terminal.Core.Release (Snap);
      end;
      Terminal.App.Renderer.Graphics.Release_Stream (R, 4_107);
      Terminal.Core.Finalize (Cursor_T);
   end;

   Terminal.App.Renderer.Graphics.Release_Stream (R, 4_106);

   declare
      Payload : constant String :=
        "Gf=100,a=T,C=1,c=1,r=1;iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJAMaU4gAAAABJRU5ErkJggg==";
   begin
      Terminal.Core.Feed
        (T,
         To_Bytes (ASCII.ESC & "_" & Payload & ASCII.ESC & "\"),
         Feed_Status);
      Assert (Feed_Status = Terminal.Core.Ok, "kitty PNG image feed failed");
      Render_And_Complete_Graphics (T);
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "kitty PNG image render failed");

      declare
         Diagnostics : constant Terminal.App.Renderer.Renderer_Diagnostics :=
           Terminal.App.Renderer.Diagnostics (R);
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Testing.Last_Frame (R);
      begin
         Assert
           (Diagnostics.Last_Image_Protocol =
            Terminal.App.Render_Model.Image_Kitty,
            "kitty PNG image diagnostic protocol");
         Assert
           (Diagnostics.Last_Image_Raw_Format = 32
            and then Diagnostics.Last_Image_Pixel_Width = 1
            and then Diagnostics.Last_Image_Pixel_Height = 1,
            "kitty PNG image diagnostic pixel metadata");
         Assert
           (Diagnostics.Last_Image_Decoded_Preview_Length = 4,
            "kitty PNG image decoded byte length");
         Assert
           (Diagnostics.Last_Image_Decoded_Preview_Bytes (1) = 16#FF#
            and then Diagnostics.Last_Image_Decoded_Preview_Bytes (2) = 16#00#
            and then Diagnostics.Last_Image_Decoded_Preview_Bytes (3) = 16#00#
            and then Diagnostics.Last_Image_Decoded_Preview_Bytes (4) = 16#FF#,
            "kitty PNG image first RGBA pixel");
         Assert
           (not Diagnostics.Last_Image_Placeholder,
            "kitty PNG image should be textured");
         Assert
           (Frame.Images (1).Protocol = Terminal.App.Render_Model.Image_Kitty
            and then Frame.Images (1).Raw_Format = 32
            and then Frame.Images (1).Pixel_Width = 1
            and then Frame.Images (1).Pixel_Height = 1
            and then Frame.Images (1).Decoded_Row_Stride_Bytes = 4,
            "kitty PNG image command pixel metadata");
         Assert
           (Frame.Images (1).Decoded_Bytes /= null
            and then Frame.Images (1).Decoded_Source =
              Terminal.App.Render_Model.Image_Decoded_Source_Buffer
            and then Frame.Images (1).Encoded_Source_Bytes = null,
            "kitty PNG image command should retain decoded pixels");
         Assert
           (not Frame.Images (1).Placeholder,
            "kitty PNG image command should be textured");
      end;
   end;

   Terminal.App.Renderer.Graphics.Release_Stream (R, 4_106);
   Terminal.Core.Set_Graphics_Stream_ID (T, 4_107);

   declare
      First_Chunk : constant String :=
        "Gf=100,a=T,C=1,c=1,r=1,m=1;iVBORw0KGgoAAAANSUhEUgAA";
      Middle_Chunk : constant String :=
        "Gm=1;AAEAAAABCAIAAACQd1PeAAAA";
      Last_Chunk : constant String :=
        "Gm=0;DUlEQVR4nGP4z8AAAAMBAQDJAMaU4gAAAABJRU5ErkJggg==";
   begin
      Terminal.Core.Feed
        (T,
         To_Bytes (ASCII.ESC & "_" & First_Chunk & ASCII.ESC & "\"),
         Feed_Status);
      Assert
        (Feed_Status = Terminal.Core.Ok,
         "chunked kitty PNG first chunk feed failed");

      Render_And_Complete_Graphics (T);
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "chunked kitty PNG first render failed");
      Assert
        (Terminal.App.Renderer.Diagnostics (R).Last_Image_Count = 0,
         "chunked kitty PNG first chunk should wait for final chunk");

      Terminal.Core.Feed
        (T,
         To_Bytes (ASCII.ESC & "_" & Middle_Chunk & ASCII.ESC & "\"),
         Feed_Status);
      Assert
        (Feed_Status = Terminal.Core.Ok,
         "chunked kitty PNG middle chunk feed failed");

      Render_And_Complete_Graphics (T);
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "chunked kitty PNG middle render failed");
      Assert
        (Terminal.App.Renderer.Diagnostics (R).Last_Image_Count = 0,
         "chunked kitty PNG middle chunk should wait for final chunk");

      Terminal.Core.Feed
        (T,
         To_Bytes (ASCII.ESC & "_" & Last_Chunk & ASCII.ESC & "\"),
         Feed_Status);
      Assert
        (Feed_Status = Terminal.Core.Ok,
         "chunked kitty PNG final chunk feed failed");

      Render_And_Complete_Graphics (T);
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "chunked kitty PNG final render failed");

      declare
         Diagnostics : constant Terminal.App.Renderer.Renderer_Diagnostics :=
           Terminal.App.Renderer.Diagnostics (R);
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Testing.Last_Frame (R);
      begin
         Assert
           (Diagnostics.Last_Image_Protocol =
            Terminal.App.Render_Model.Image_Kitty,
            "chunked kitty PNG image diagnostic protocol");
         Assert
           (Diagnostics.Last_Image_Raw_Format = 32
            and then Diagnostics.Last_Image_Pixel_Width = 1
            and then Diagnostics.Last_Image_Pixel_Height = 1,
            "chunked kitty PNG image diagnostic pixel metadata");
         Assert
           (Diagnostics.Last_Image_Decoded_Preview_Length = 4,
            "chunked kitty PNG decoded byte length");
         Assert
           (Diagnostics.Last_Image_Encoded_Preview_Length = 0,
            "retained chunked PNG no longer owns encoded segments");
         Assert
           (Diagnostics.Last_Image_Staging_Byte_Length = 0,
            "retained chunked PNG no longer requires decode staging");
         Assert
           (Diagnostics.Last_Image_Decoded_Preview_Bytes (1) = 16#FF#
            and then Diagnostics.Last_Image_Decoded_Preview_Bytes (2) = 16#00#
            and then Diagnostics.Last_Image_Decoded_Preview_Bytes (3) = 16#00#
            and then Diagnostics.Last_Image_Decoded_Preview_Bytes (4) = 16#FF#,
            "chunked kitty PNG decoded bytes");
         Assert
           (not Diagnostics.Last_Image_Placeholder,
            "chunked kitty PNG image should be textured");
         Assert
           (Frame.Images (1).Protocol = Terminal.App.Render_Model.Image_Kitty
            and then Frame.Images (1).Pixel_Width = 1
            and then Frame.Images (1).Pixel_Height = 1
            and then Frame.Images (1).Decoded_Row_Stride_Bytes = 4,
            "chunked kitty PNG command pixel metadata");
         Assert
           (Frame.Images (1).Decoded_Bytes /= null
            and then Frame.Images (1).Decoded_Source =
              Terminal.App.Render_Model.Image_Decoded_Source_Buffer
            and then Frame.Images (1).Encoded_Source_Bytes = null,
            "chunked kitty PNG command should retain decoded pixels");
         Assert
           (not Frame.Images (1).Placeholder,
            "chunked kitty PNG command should be textured");
      end;
   end;

   Terminal.App.Renderer.Graphics.Release_Stream (R, 4_107);
   Terminal.Core.Set_Graphics_Stream_ID (T, 4_108);

   Terminal.Core.Feed
     (T,
      To_Bytes (ASCII.ESC & "Pq~" & ASCII.ESC & "\"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "sixel graphics feed failed");

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert
     (Render_Status = Terminal.App.Renderer.Ok,
      "sixel graphics render failed");

   declare
      Diagnostics : constant Terminal.App.Renderer.Renderer_Diagnostics :=
        Terminal.App.Renderer.Diagnostics (R);
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Testing.Last_Frame (R);
   begin
      Assert
        (Diagnostics.Last_Image_Protocol =
         Terminal.App.Render_Model.Image_Sixel,
         "sixel graphics image diagnostic protocol");
      Assert
        (Diagnostics.Last_Image_Raw_Format = 32
         and then Diagnostics.Last_Image_Pixel_Width = 1
         and then Diagnostics.Last_Image_Pixel_Height = 6,
         "sixel graphics image diagnostic pixel metadata");
      Assert
        (Diagnostics.Last_Image_Decoded_Preview_Length = 24,
         "sixel graphics image decoded byte length");
      Assert
        (Diagnostics.Last_Image_Decoded_Preview_Bytes (1) = 16#FF#
         and then Diagnostics.Last_Image_Decoded_Preview_Bytes (2) = 16#FF#
         and then Diagnostics.Last_Image_Decoded_Preview_Bytes (3) = 16#FF#
         and then Diagnostics.Last_Image_Decoded_Preview_Bytes (4) = 16#FF#,
         "sixel graphics first RGBA pixel");
      Assert
        (not Diagnostics.Last_Image_Placeholder,
         "sixel graphics image should be textured");
      Assert
        (Frame.Images (1).Protocol = Terminal.App.Render_Model.Image_Sixel
         and then Frame.Images (1).Raw_Format = 32
         and then Frame.Images (1).Pixel_Width = 1
         and then Frame.Images (1).Pixel_Height = 6
         and then Frame.Images (1).Decoded_Row_Stride_Bytes = 4,
         "sixel graphics command pixel metadata");
      Assert
         (Frame.Images (1).Decoded_Bytes /= null
         and then Frame.Images (1).Decoded_Source =
           Terminal.App.Render_Model.Image_Decoded_Source_Buffer
         and then Frame.Images (1).Encoded_Source_Bytes = null,
         "sixel retained command should borrow resolved palette pixels");
      Assert
        (not Frame.Images (1).Placeholder,
         "sixel graphics command should be textured");
      Assert
        (Terminal.App.Renderer.Image_Status_Label (Diagnostics) =
         Bounded_Image_Label
           ("image sixel size="
         & "1"
         & "x"
         & "6"
         & " pixels=1x6 format=32 payload=0 payload-complete preview=24/0 bytes=FFFFFFFF textured decoded"),
         "sixel graphics image diagnostic status label");
   end;

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Snap.Graphics := (others => <>);
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert
     (Render_Status = Terminal.App.Renderer.Ok,
      "retained sixel render failed");
   declare
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Testing.Last_Frame (R);
   begin
      Assert
        (Frame.Image_Count = 1
         and then Frame.Images (1).Protocol =
           Terminal.App.Render_Model.Image_Sixel,
         "sixel image should persist after its graphics event is consumed");
   end;

   Terminal.App.Renderer.Graphics.Release_Stream (R, 4_108);

   declare
      Aux_T : Terminal.Core.Terminal;
      Aux_Init : Terminal.Core.Initialize_Status;
      Aux_Feed : Terminal.Core.Feed_Status;
      Aux_Objects_Before : constant Natural :=
        Terminal.App.Renderer.Diagnostics (R).Image_Object_Count;
      Aux_Placements_Before : constant Natural :=
        Terminal.App.Renderer.Diagnostics (R).Placement_Count;

      procedure Feed_Render_And_Discard (Text : String; Label_Text : String) is
         Event : Terminal.Core.Graphics_Event;
         Snap : Terminal.Core.Render_Snapshot;
      begin
         Terminal.Core.Feed (Aux_T, To_Bytes (Text), Aux_Feed);
         Assert (Aux_Feed = Terminal.Core.Ok, Label_Text & " feed");
         Terminal.Core.Peek_Graphics_Event (Aux_T, Event);
         Assert (Event.Pending, Label_Text & " event");
         Terminal.Core.Snapshot (Aux_T, Snap);
         Snap.Graphics := Event;
         Terminal.App.Renderer.Render (R, Snap, Render_Status);
         Assert (Render_Status = Terminal.App.Renderer.Ok, Label_Text & " render");
         Terminal.Core.Release (Snap);
         Terminal.Core.Discard_Graphics_Event (Aux_T);
      end Feed_Render_And_Discard;
   begin
      Terminal.Core.Initialize (Aux_T, 4, 10, 100, Aux_Init);
      Assert (Aux_Init = Terminal.Core.Ok, "auxiliary coexist terminal initialize");
      Terminal.Core.Set_Graphics_Stream_ID (Aux_T, 4_109);
      Feed_Render_And_Discard
        (ASCII.ESC & "Pq~" & ASCII.ESC & "\",
         "coexisting sixel image");
      Feed_Render_And_Discard
        (ASCII.ESC & "]1337;File=inline=1;doNotMoveCursor=1;width=1;height=1:"
         & "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJAMaU4gAAAABJRU5ErkJggg=="
         & ASCII.BEL,
         "coexisting iTerm2 image");
      declare
         Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (Aux_T);
      begin
         Snap.Graphics := (others => <>);
         Terminal.App.Renderer.Render (R, Snap, Render_Status);
         Terminal.Core.Release (Snap);
      end;
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "coexisting auxiliary retained render");
      declare
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Testing.Last_Frame (R);
         Aux_Diagnostics : constant Terminal.App.Renderer.Renderer_Diagnostics :=
           Terminal.App.Renderer.Diagnostics (R);
         Saw_Sixel : Boolean := False;
         Saw_ITerm2 : Boolean := False;
      begin
         for I in 1 .. Frame.Image_Count loop
            Saw_Sixel := Saw_Sixel
              or else Frame.Images (I).Protocol =
                Terminal.App.Render_Model.Image_Sixel;
            Saw_ITerm2 := Saw_ITerm2
              or else Frame.Images (I).Protocol =
                Terminal.App.Render_Model.Image_ITerm2;
         end loop;
         Assert
           (Frame.Image_Count = 2 and then Saw_Sixel and then Saw_ITerm2,
            "retained Sixel and iTerm2 images should coexist");
         Assert
           (Aux_Diagnostics.Image_Object_Count = Aux_Objects_Before + 2
            and then Aux_Diagnostics.Placement_Count =
              Aux_Placements_Before + 2
            and then Aux_Diagnostics.Kitty_Image_Object_Count =
              Aux_Diagnostics.Image_Object_Count
            and then Aux_Diagnostics.Kitty_Placement_Count =
              Aux_Diagnostics.Placement_Count,
            "shared graphics-store diagnostics are protocol-neutral");
      end;
      Terminal.App.Renderer.Graphics.Release_Stream (R, 4_109);
      Terminal.Core.Finalize (Aux_T);
   end;

   declare
      Retry_T : Terminal.Core.Terminal;
      Retry_Init : Terminal.Core.Initialize_Status;
      Retry_Feed : Terminal.Core.Feed_Status;
      Retry_Tabs : Terminal.App.Tabs.Tab_State;
      Retry_Splits : Terminal.App.Splits.Split_State;

      procedure Retry_Event (Text : String; Label_Text : String) is
         Event : Terminal.Core.Graphics_Event;
         Snapshots : Terminal.App.Renderer.Snapshot_Array (1 .. 1);
         Objects_Before : constant Natural :=
           Terminal.App.Renderer.Diagnostics (R).Image_Object_Count;
         Placements_Before : constant Natural :=
           Terminal.App.Renderer.Diagnostics (R).Placement_Count;
      begin
         Terminal.Core.Feed (Retry_T, To_Bytes (Text), Retry_Feed);
         Assert (Retry_Feed = Terminal.Core.Ok, Label_Text & " feed");
         Terminal.Core.Peek_Graphics_Event (Retry_T, Event);
         Assert (Event.Pending, Label_Text & " event");
         Terminal.Core.Snapshot (Retry_T, Snapshots (1));
         Snapshots (1).Graphics := Event;
         for Attempt in 1 .. 2 loop
            Terminal.App.Renderer.Layout.Render_App
              (R,
               Snapshots,
               1,
               Terminal.App.Tabs.Snapshot (Retry_Tabs),
               Terminal.App.Splits.Snapshot (Retry_Splits),
               Render_Status);
            Assert
              (Render_Status = Terminal.App.Renderer.Ok,
               Label_Text & " retry render");
            Assert
              (Terminal.App.Renderer.Diagnostics (R).Image_Object_Count =
                 Objects_Before + 1
               and then
                 Terminal.App.Renderer.Diagnostics (R).Placement_Count =
                   Placements_Before + 1,
               Label_Text & " retry does not duplicate resources");
         end loop;
         Terminal.Core.Release (Snapshots (1));
         Terminal.Core.Discard_Graphics_Event (Retry_T);
         Terminal.App.Renderer.Graphics.Commit_Visible_Events (R);
      end Retry_Event;
   begin
      Terminal.Core.Initialize (Retry_T, 4, 10, 100, Retry_Init);
      Assert (Retry_Init = Terminal.Core.Ok, "auxiliary retry initialize");
      Terminal.Core.Set_Graphics_Stream_ID (Retry_T, 4_110);
      Terminal.App.Tabs.Initialize (Retry_Tabs);
      Terminal.App.Splits.Initialize (Retry_Splits);
      Retry_Event
        (ASCII.ESC & "Pq~" & ASCII.ESC & "\",
         "Sixel presentation");
      Retry_Event
        (ASCII.ESC & "]1337;File=inline=1;doNotMoveCursor=1;width=1;height=1:"
         & "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJAMaU4gAAAABJRU5ErkJggg=="
         & ASCII.BEL,
         "iTerm2 presentation");
      Terminal.App.Renderer.Graphics.Release_Stream (R, 4_110);
      Terminal.Core.Finalize (Retry_T);
   end;

end Run_Protocol_Transactions;
