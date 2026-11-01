with Ada.Text_IO;
with AUnit.Assertions;
with Interfaces;
with System;
with Terminal.Common.Bytes;
with Terminal.Core;
with Terminal.App.Hyperlinks;
with Terminal.App.Image_Media;
with Terminal.App.Render_Model;
with Terminal.App.Renderer;
with Terminal.App.Renderer.Graphics;
with Terminal.App.Renderer.Layout;
with Terminal.App.Renderer.Testing;
with Terminal.App.Scrollback_View;
with Terminal.App.Splits;
with Terminal.App.Tabs;

procedure Renderer_Metrics_Smoke is
   use Terminal.Common.Bytes;
   use type Terminal.Common.Code_Point;
   use type Terminal.App.Renderer.Init_Status;
   use type Terminal.App.Renderer.Graphics_Resource_Limits;
   use type Terminal.App.Renderer.Render_Status;
   use type Terminal.App.Image_Media.Decode_Status;
   use type Terminal.App.Render_Model.Image_Decode_Status;
   use type Terminal.App.Render_Model.Image_Decoded_Source_Kind;
   use type Terminal.App.Render_Model.Image_Data_Access;
   use type Terminal.App.Render_Model.Image_Data_View;
   use type Terminal.App.Render_Model.Image_Protocol;
   use type Terminal.App.Render_Model.Rectangle_Layer;
   use type Terminal.App.Render_Model.Text_Run_Direction;
   use type Terminal.App.Render_Model.Text_Run_Kind;
   use type Terminal.App.Render_Model.Text_Run_Script;
   use type Terminal.App.Render_Model.Text_Run_Shape_Status;
   use type System.Address;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Unsigned_64;
   use type Terminal.Core.Feed_Status;


   use type Terminal.Core.Graphics_ID;
   use type Terminal.Core.Initialize_Status;
   use type Terminal.Core.Kitty_Graphics_Result_Code;
   use type Terminal.App.Splits.Split_Status;
   use type Terminal.App.Tabs.Tab_Status;

   --  AUnit's Assert outside a test case raises with no word of what
   --  failed; say it on standard error first, so a CI log names the check.
   procedure Assert (Condition : Boolean; Message : String);

   procedure Assert (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "FAILED: " & Message);
         AUnit.Assertions.Assert (False, Message);
      end if;
   end Assert;

   R      : Terminal.App.Renderer.Renderer;
   Status : Terminal.App.Renderer.Init_Status;
   T      : Terminal.Core.Terminal;
   Core_Status : Terminal.Core.Initialize_Status;
   Feed_Status : Terminal.Core.Feed_Status;
   Render_Status : Terminal.App.Renderer.Render_Status;

   function To_Bytes (Text : String) return Byte_Array is
      Result : Byte_Array (1 .. Text'Length);
   begin
      for I in Text'Range loop
         Result (I - Text'First + 1) := Byte (Character'Pos (Text (I)));
      end loop;
      return Result;
   end To_Bytes;

   function Trimmed_Natural (Value : Natural) return String is
      Text : constant String := Natural'Image (Value);
   begin
      return Text (Text'First + 1 .. Text'Last);
   end Trimmed_Natural;

   function Bounded_Image_Label (Text : String) return String is
     (if Text'Length <= Terminal.App.Renderer.Max_Status_Label_Length
      then Text
      else Text
        (Text'First
         .. Text'First + Terminal.App.Renderer.Max_Status_Label_Length - 1));

   function Repeat_Char (Ch : Character; Count : Natural) return String is
      Result : String (1 .. Count);
   begin
      for I in Result'Range loop
         Result (I) := Ch;
      end loop;
      return Result;
   end Repeat_Char;

   procedure Render_And_Complete_Graphics
     (Target : in out Terminal.Core.Terminal)
   is
      Rendered : Boolean := False;
   begin
      loop
         declare
            Event : Terminal.Core.Graphics_Event;
         begin
            Terminal.Core.Peek_Graphics_Event (Target, Event);
            exit when not Event.Pending;
            declare
               Snap : Terminal.Core.Render_Snapshot :=
                 Terminal.Core.Snapshot (Target);
               Result : Terminal.Core.Kitty_Graphics_Result;
            begin
               Snap.Graphics := Event;
               Terminal.App.Renderer.Render (R, Snap, Render_Status);
               Result := Terminal.App.Renderer.Graphics.Result (R, Event);
               Terminal.Core.Release (Snap);
               Terminal.Core.Complete_Graphics_Event (Target, Event, Result);
               Terminal.App.Renderer.Graphics.Commit_Visible_Events (R);
               Rendered := True;
            end;
            exit when Render_Status /= Terminal.App.Renderer.Ok;
         end;
      end loop;

      if not Rendered then
         declare
            Snap : Terminal.Core.Render_Snapshot :=
              Terminal.Core.Snapshot (Target);
         begin
            Terminal.App.Renderer.Render (R, Snap, Render_Status);
            Terminal.Core.Release (Snap);
         end;
      end if;
   end Render_And_Complete_Graphics;

   procedure Assert_Close
     (Actual  : Float;
      Expected : Float;
      Message  : String)
   is
      Diff : constant Float := abs (Actual - Expected);
   begin
      Assert (Diff < 0.001, Message);
   end Assert_Close;

   procedure Run_Rendering_Baseline is separate;
   procedure Run_Protocol_Transactions is separate;
   procedure Run_Failure_And_Quota_Cases is separate;
   procedure Run_Composition_And_Lifetime_Cases is separate;
begin
   Terminal.App.Renderer.Initialize_Headless (R, Status);
   Assert (Status = Terminal.App.Renderer.Ok, "renderer initialize failed");
   Assert
     (Terminal.App.Renderer.Cell_Height (R) >= 16,
      "cell height should keep at least the requested pixel size");
   Assert
     (Terminal.App.Renderer.Cell_Width (R) > 8,
      "cell width should include measured glyph advance and breathing room");


   Run_Rendering_Baseline;
   Run_Protocol_Transactions;
   Run_Failure_And_Quota_Cases;
   Run_Composition_And_Lifetime_Cases;

   Terminal.App.Renderer.Finalize (R);
end Renderer_Metrics_Smoke;
