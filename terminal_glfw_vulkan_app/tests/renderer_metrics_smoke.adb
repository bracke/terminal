with Terminal.Core.Snapshot_Editing;
with Ada.Exceptions;
with Ada.Text_IO;
with AUnit.Assertions;
with Interfaces;
with System;
with Terminal.Common.Bytes;
with Terminal.Core;
with Terminal.App.Hyperlinks;
with Terminal.App.Graphics;
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
   use type Terminal.App.Renderer.Graphics.Stage_Event_Status;
   use type Terminal.App.Renderer.Graphics.Resource_Limit_Update_Status;
   use type Terminal.App.Image_Media.Decode_Status;
   use type Terminal.App.Render_Model.Image_Decode_Status;
   use type Terminal.App.Render_Model.Image_Decoded_Source_Kind;
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
   use type Terminal.Core.Graphics_Completion_Code;
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

   type Suite_Context is limited record
      Renderer      : Terminal.App.Renderer.Renderer;
      Init_Status   : Terminal.App.Renderer.Init_Status;
      Core          : Terminal.Core.Terminal;
      Core_Status   : Terminal.Core.Initialize_Status;
      Feed_Status   : Terminal.Core.Feed_Status;
      Render_Status : Terminal.App.Renderer.Render_Status;
   end record;

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
     (Context : in out Suite_Context;
      Target  : in out Terminal.Core.Terminal)
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
               Result : Terminal.Core.Graphics_Completion;
            begin
               Terminal.Core.Snapshot_Editing.Set_Graphics (Snap, Event);
               Terminal.App.Renderer.Render
                 (Context.Renderer, Snap, Context.Render_Status);
               Result := Terminal.App.Renderer.Graphics.Result
                 (Context.Renderer, Event);
               Terminal.Core.Release (Snap);
               Terminal.Core.Complete_Graphics_Event (Target, Event, Result);
               Terminal.App.Renderer.Graphics.Commit_Visible_Events
                 (Context.Renderer);
               Rendered := True;
            end;
            exit when Context.Render_Status /= Terminal.App.Renderer.Ok;
         end;
      end loop;

      if not Rendered then
         declare
            Snap : Terminal.Core.Render_Snapshot :=
              Terminal.Core.Snapshot (Target);
         begin
            Terminal.App.Renderer.Render
              (Context.Renderer, Snap, Context.Render_Status);
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

   --  Keep every case procedure directly under the suite.  This preserves
   --  shared fixture access without the former three-level subunit hierarchy.
   procedure Run_Hyperlink_And_Diagnostic_Cases
     (Context : in out Suite_Context) is separate;
   procedure Run_Placement_And_Cropping_Cases
     (Context : in out Suite_Context) is separate;
   procedure Run_Deletion_Scope_Cases
     (Context : in out Suite_Context) is separate;
   procedure Run_Image_Number_Cases
     (Context : in out Suite_Context) is separate;
   procedure Run_Relative_Placement_Cases
     (Context : in out Suite_Context) is separate;
   procedure Run_Virtual_Parent_And_RGB_Cases
     (Context : in out Suite_Context) is separate;
   procedure Run_Chunked_Raw_Cases
     (Context : in out Suite_Context) is separate;
   procedure Run_Query_And_Validation_Cases
     (Context : in out Suite_Context) is separate;
   procedure Run_Quota_And_Segmentation_Cases
     (Context : in out Suite_Context) is separate;
   procedure Run_Large_Payload_Cases
     (Context : in out Suite_Context) is separate;
   procedure Run_Raw_And_ITerm2_Cases
     (Context : in out Suite_Context) is separate;
   procedure Run_Encoded_And_Sixel_Cases
     (Context : in out Suite_Context) is separate;
   procedure Run_Protocol_Diagnostic_Cases
     (Context : in out Suite_Context) is separate;
   procedure Run_Failure_And_Colour_Cases
     (Context : in out Suite_Context) is separate;
   procedure Run_Decoration_Cases
     (Context : in out Suite_Context) is separate;
   procedure Run_Cluster_Shaping_Cases
     (Context : in out Suite_Context) is separate;
   procedure Run_Emoji_Cluster_Cases
     (Context : in out Suite_Context) is separate;
   procedure Run_Shaping_Fallback_Cases
     (Context : in out Suite_Context) is separate;
   procedure Run_Image_Quota_Cases
     (Context : in out Suite_Context) is separate;
   procedure Run_Lifecycle_And_Multi_View_Cases
     (Context : in out Suite_Context) is separate;
   procedure Run_Scrollback_Placement_Cases
     (Context : in out Suite_Context) is separate;

   procedure Run_Rendering_Baseline
     (Context : in out Suite_Context) is separate;
   procedure Run_Protocol_Transactions
     (Context : in out Suite_Context) is separate;
   procedure Run_Failure_And_Quota_Cases
     (Context : in out Suite_Context) is separate;
   procedure Run_Composition_And_Lifetime_Cases
     (Context : in out Suite_Context) is separate;

   type Suite_Action is not null access procedure
     (Context : in out Suite_Context);
   Failure_Count : Natural := 0;
   First_Failure : Ada.Exceptions.Exception_Occurrence;

   procedure Run_Isolated_Suite
     (Name   : String;
      Action : Suite_Action)
   is
      Context : Suite_Context;
   begin
      Terminal.App.Renderer.Initialize_Headless
        (Context.Renderer, Context.Init_Status);
      Assert
        (Context.Init_Status = Terminal.App.Renderer.Ok,
         Name & " initialize failed");
      Terminal.Core.Initialize
        (Context.Core, 1, 1, 10, Context.Core_Status);
      Assert
        (Context.Core_Status = Terminal.Core.Ok,
         Name & " core initialize failed");
      Assert
        (Terminal.App.Renderer.Cell_Height (Context.Renderer) >= 16,
         Name & " cell height");
      Assert
        (Terminal.App.Renderer.Cell_Width (Context.Renderer) > 8,
         Name & " measured cell width");
      Action.all (Context);
      Terminal.App.Renderer.Finalize (Context.Renderer);
      Terminal.Core.Finalize (Context.Core);
   exception
      when E : others =>
         if Failure_Count = 0 then
            Ada.Exceptions.Save_Occurrence (First_Failure, E);
         end if;
         Failure_Count := Failure_Count + 1;
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "FAILED SUITE: " & Name & ": "
            & Ada.Exceptions.Exception_Information (E));
         Terminal.App.Renderer.Finalize (Context.Renderer);
         Terminal.Core.Finalize (Context.Core);
   end Run_Isolated_Suite;
begin
   Run_Isolated_Suite ("rendering baseline", Run_Rendering_Baseline'Access);
   Run_Isolated_Suite
     ("protocol transactions", Run_Protocol_Transactions'Access);
   Run_Isolated_Suite
     ("failure and quota", Run_Failure_And_Quota_Cases'Access);
   Run_Isolated_Suite
     ("composition and lifetime", Run_Composition_And_Lifetime_Cases'Access);
   if Failure_Count > 0 then
      Ada.Exceptions.Reraise_Occurrence (First_Failure);
   end if;
end Renderer_Metrics_Smoke;
