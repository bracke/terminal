with Terminal.Core.Snapshot_Editing;
separate (Renderer_Metrics_Smoke)
procedure Run_Query_And_Validation_Cases (Context : in out Suite_Context) is
   R : Terminal.App.Renderer.Renderer renames Context.Renderer;
   T : Terminal.Core.Terminal renames Context.Core;
   Feed_Status : Terminal.Core.Feed_Status renames Context.Feed_Status;
   Render_Status : Terminal.App.Renderer.Render_Status renames Context.Render_Status;
begin
   declare
      Chunk_T : Terminal.Core.Terminal;
      Chunk_Init : Terminal.Core.Initialize_Status;
      Chunk_Feed : Terminal.Core.Feed_Status;
      Event : Terminal.Core.Graphics_Event;
      Result : Terminal.Core.Graphics_Completion;
      Tabs : Terminal.App.Tabs.Tab_State;
      Splits : Terminal.App.Splits.Split_State;
      Objects_Before : constant Natural :=
        Terminal.App.Renderer.Diagnostics (R).Kitty_Image_Object_Count;

      procedure Feed_Render
        (Text : String;
         Expected : Terminal.Core.Graphics_Completion_Code;
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
              (Expected = Terminal.Core.Graphics_No_Response,
               Message & " incomplete transaction result");
            return;
         end if;
         Terminal.Core.Snapshot (Chunk_T, Snapshots (1));
         Terminal.Core.Snapshot_Editing.Set_Graphics (Snapshots (1), Event);
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
         Assert
           (Result.Code = Expected,
            Message & " protocol result expected="
            & Terminal.Core.Graphics_Completion_Code'Image (Expected)
            & " actual="
            & Terminal.Core.Graphics_Completion_Code'Image (Result.Code)
            & " action="
            & Terminal.App.Graphics.Header (Event).Kitty_Action);
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
         Terminal.Core.Graphics_EINVAL,
         "non-final chunk alignment rejection");
      Feed_Render
        ("Gq=2,a=t,i=91,f=32,s=1,v=1,m=1;"
         & Repeat_Char ('A', 4_097),
         Terminal.Core.Graphics_EINVAL,
         "oversized chunk rejection");
      Feed_Render
        ("Gq=2,a=t,i=91,f=32,s=1,v=1,m=2;AAAA",
         Terminal.Core.Graphics_EINVAL,
         "invalid chunk flag rejection");

      Feed_Render
        ("Gq=2,a=t,i=92,f=32,s=1,v=1,m=1;AAAA",
         Terminal.Core.Graphics_No_Response,
         "valid first chunk retention");
      Feed_Render
        ("Gm=0,i=92;AA==",
         Terminal.Core.Graphics_EINVAL,
         "continuation control rejection");

      Feed_Render
        ("Gq=2,a=t,i=94,f=32,s=1,v=1,m=1;/wAA",
         Terminal.Core.Graphics_No_Response,
         "delete-cancel first chunk retention");
      Feed_Render
        ("Gq=2,a=d,d=i,i=94",
         Terminal.Core.Graphics_OK,
         "delete command aborts partial upload");
      Feed_Render
        ("Gq=2,a=t,i=94,f=32,s=1,v=1,m=1;/wAA",
         Terminal.Core.Graphics_No_Response,
         "fresh chunk after delete cancellation");
      Feed_Render
        ("Gq=2,m=0;/w==",
         Terminal.Core.Graphics_OK,
         "completed chunk after delete cancellation");

      Feed_Render
        ("Gq=2,a=t,i=92,f=32,s=1,v=1;/wAA/w==",
         Terminal.Core.Graphics_OK,
         "post-rejection transaction recovery");
      Assert
        (Terminal.App.Renderer.Diagnostics (R).Kitty_Image_Object_Count =
           Objects_Before + 2,
         "valid transfer succeeds after malformed chunks");

      Feed_Render
        ("Gq=2,a=t,i=180,i=181,f=32,s=1,v=1;/wAA/w==",
         Terminal.Core.Graphics_EINVAL,
         "duplicate control rejection");
      Feed_Render
        ("Gq=2,a=t,i=182,f=32,s=bad,v=1;/wAA/w==",
         Terminal.Core.Graphics_EINVAL,
         "malformed numeric control rejection");
      Feed_Render
        ("Gq=2,a=p,i=92;AAAA",
         Terminal.Core.Graphics_EINVAL,
         "put action payload rejection");
      Feed_Render
        ("Gq=2,a=p,i=92,c=1,r=16385,C=1",
         Terminal.Core.Graphics_EINVAL,
         "oversized logical placement rejection");
      Feed_Render
        ("Gq=2,a=t,i=183,f=32,s=1,v=1",
         Terminal.Core.Graphics_EINVAL,
         "transmit action missing payload rejection");
      Feed_Render
        ("Gq=2,a=x,i=184",
         Terminal.Core.Graphics_ENOTSUP,
         "unsupported action rejection");

      Feed_Render
        ("Ga=q,i=200,f=32,s=1,v=1;/wAA/w==",
         Terminal.Core.Graphics_OK,
         "query validates direct raw payload");
      Feed_Render
        ("Ga=q,i=201,f=32,s=1,v=1;%%%%",
         Terminal.Core.Graphics_EINVAL,
         "query rejects invalid direct payload");
      Feed_Render
        ("Ga=q,i=202,f=32,s=1,v=1,o=z;eJz7z8DwHwAE/wH/",
         Terminal.Core.Graphics_OK,
         "query validates compressed direct payload");
      Feed_Render
        ("Ga=q,i=204,f=100,o=z;"
         & "eJzrDPBz5+WS4mJgYOD19HAJAtKMIMzBBCQnlAff"
         & "A1I8ni6OIRVzkn+cP8DAwMzIyHDy36T3QHEGT1c/l3VOCU0Azm0QjQ==",
         Terminal.Core.Graphics_EINVAL,
         "direct compressed PNG query requires inflated size");
      Feed_Render
        ("Ga=q,i=203,f=32,s=1,v=1,t=x;/wAA/w==",
         Terminal.Core.Graphics_ENOTSUP,
         "query rejects unsupported transfer medium");
      Assert
        (Terminal.App.Renderer.Diagnostics (R).Kitty_Image_Object_Count =
           Objects_Before + 2,
         "query validation must not retain image objects");

      Feed_Render
        ("Gq=2,a=T,i=95,f=32,s=1,v=1,c=1,r=1,C=1,o=z;"
         & "eJz7z8DwHwAE/wH/",
         Terminal.Core.Graphics_OK,
         "zlib raw direct transfer");
      Feed_Render
        ("Gq=2,a=T,i=96,f=100,S=69,c=1,r=1,C=1,o=z;"
         & "eJzrDPBz5+WS4mJgYOD19HAJAtKMIMzBBCQnlAff"
         & "A1I8ni6OIRVzkn+cP8DAwMzIyHDy36T3QHEGT1c/l3VOCU0Azm0QjQ==",
         Terminal.Core.Graphics_OK,
         "zlib PNG direct transfer");
      Feed_Render
        ("Gq=2,a=T,i=97,f=32,s=1,v=1,c=1,r=1,C=1,o=z,m=1;"
         & "eJz7z8Dw",
         Terminal.Core.Graphics_No_Response,
         "zlib raw first chunk");
      Feed_Render
        ("Gq=2,m=0;HwAE/wH/",
         Terminal.Core.Graphics_OK,
         "zlib raw final chunk");
      Feed_Render
        ("Gq=2,a=T,i=98,f=32,s=1,v=1,c=1,r=1,C=1,o=z;"
         & "eJz7z8DwHwAE/wHA",
         Terminal.Core.Graphics_EINVAL,
         "zlib checksum rejection");
      Feed_Render
        ("Gq=2,a=T,i=99,f=100,c=1,r=1,C=1,o=z;"
         & "eJzrDPBz5+WS4mJgYOD19HAJAtKMIMzBBCQnlAff"
         & "A1I8ni6OIRVzkn+cP8DAwMzIyHDy36T3QHEGT1c/l3VOCU0Azm0QjQ==",
         Terminal.Core.Graphics_EINVAL,
         "zlib PNG size requirement");
      Assert
        (Terminal.App.Renderer.Diagnostics (R).Kitty_Image_Object_Count =
           Objects_Before + 5,
         "zlib transfers install only validated image objects");
      Feed_Render
        ("Gq=2,a=T,f=32,s=1,v=1,c=1,r=1,C=1,o=z;"
         & "eJz7z8DwHwAE/wH/",
         Terminal.Core.Graphics_OK,
         "anonymous zlib raw display");
      Assert
        (Terminal.App.Renderer.Diagnostics (R).Kitty_Image_Object_Count =
           Objects_Before + 6,
         "anonymous zlib display retains an anonymous image object");

      Feed_Render
        ("Gq=2,a=t,i=110,f=32,s=2,v=1;/wAA/wD/AP8=",
         Terminal.Core.Graphics_OK,
         "geometry source transmission");
      Feed_Render
        ("Gq=2,a=p,i=110,p=10,C=1",
         Terminal.Core.Graphics_OK,
         "natural geometry placement");
      Feed_Render
        ("Gq=2,a=p,i=110,p=11,c=2,C=1",
         Terminal.Core.Graphics_OK,
         "one-sided geometry placement");
      Feed_Render
        ("Gq=2,a=p,i=110,p=12,c=2,r=2,C=1",
         Terminal.Core.Graphics_OK,
         "letterboxed geometry placement");
      Feed_Render
        ("Gq=2,a=p,i=110,p=13,c=0,C=1",
         Terminal.Core.Graphics_EINVAL,
         "zero column geometry rejection");
      Feed_Render
        ("Gq=2,a=p,i=110,p=14,x=2,C=1",
         Terminal.Core.Graphics_EINVAL,
         "empty source crop rejection");
      Feed_Render
        ("Gq=2,a=p,i=110,p=15,X="
         & Trimmed_Natural (Terminal.App.Renderer.Cell_Width (R))
         & ",C=1",
         Terminal.Core.Graphics_EINVAL,
         "out-of-cell x offset rejection");
      Feed_Render
        ("Gq=2,a=p,i=110,p=16,x=bad,C=1",
         Terminal.Core.Graphics_EINVAL,
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
         Terminal.Core.Graphics_OK,
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
end Run_Query_And_Validation_Cases;
