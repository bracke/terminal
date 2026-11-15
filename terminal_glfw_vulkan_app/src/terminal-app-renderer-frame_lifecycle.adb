with Ada.Unchecked_Deallocation;
with Terminal.App.Frame_Image_Storage;
with Terminal.App.Vulkan_Submit;
with Terminal.App.Renderer.Animations;
with Textrender;

package body Terminal.App.Renderer.Frame_Lifecycle is
   package RM renames Terminal.App.Render_Model;
   package VS renames Terminal.App.Vulkan_Submit;
   package FIS renames Terminal.App.Frame_Image_Storage;
   use type VS.Build_Status;
   use type RM.Rectangle_Array_Access;
   use type RM.Glyph_Array_Access;
   use type RM.Colour_Glyph_Array_Access;
   use type RM.Text_Run_Array_Access;
   use type Shaped_Run_Map_Array_Access;
   use type Terminal.App.Renderer_State.Cached_Text_Row_Array_Access;

   procedure Free_Rectangles is new Ada.Unchecked_Deallocation
     (RM.Rectangle_Array, RM.Rectangle_Array_Access);
   procedure Free_Glyphs is new Ada.Unchecked_Deallocation
     (RM.Glyph_Array, RM.Glyph_Array_Access);
   procedure Free_Text_Runs is new Ada.Unchecked_Deallocation
     (RM.Text_Run_Array, RM.Text_Run_Array_Access);
   procedure Free_Colour_Glyphs is new Ada.Unchecked_Deallocation
     (RM.Colour_Glyph_Array, RM.Colour_Glyph_Array_Access);
   procedure Free_Shaped_Run_Map is new Ada.Unchecked_Deallocation
     (Shaped_Run_Map_Array, Shaped_Run_Map_Array_Access);
   procedure Free_Cached_Rows is new Ada.Unchecked_Deallocation
     (Terminal.App.Renderer_State.Cached_Text_Row_Array,
      Terminal.App.Renderer_State.Cached_Text_Row_Array_Access);

   function Grown_Capacity
     (Current  : Natural;
      Required : Positive) return Positive
   is
   begin
      if Current >= Required then
         return Positive (Current);
      elsif Current = 0 then
         return Required;
      elsif Current <= Natural'Last / 2 then
         return Positive'Max (Required, Positive (Current * 2));
      else
         return Required;
      end if;
   end Grown_Capacity;

   procedure Reset_Counters (R : in out Renderer) is
   begin
      R.Frame_State.Rectangle_Count := 0;
      R.Frame_State.Frame_Command_Overflowed := False;
      R.Frame_State.Glyph_Count := 0;
      R.Frame_State.Colour_Glyph_Count := 0;
      R.Frame_State.Text_Run_Count := 0;
      R.Text_State.Shaped_Glyph_Count := 0;
      R.Text_State.Shaping_Fallback_Count := 0;
      R.Text_State.Text_Fallback_Run_Count := 0;
      R.Text_State.Color_Glyph_Count := 0;
      R.Text_State.Color_Emoji_Fallback_Count := 0;
      R.Text_State.Paragraph_Bidi_Fallback_Count := 0;
      R.Text_State.Missing_Glyph_Count := 0;
      R.Frame_State.Vertex_Count := 0;
      R.Frame_State.Last_Cell_Count := 0;
      R.Frame_State.Last_Dirty_Rows := 0;
      R.Frame_State.Last_Cached_Rows := 0;
      R.Frame_State.Last_Frame_Width := 0;
      R.Frame_State.Last_Frame_Height := 0;
   end Reset_Counters;

   procedure Reset (R : in out Renderer) is
   begin
      VS.Invalidate (R.Frame_State.Batch);
      FIS.Reset (R.Frame_State.Frame_Images);
      Reset_Counters (R);
   end Reset;

   procedure Release (R : in out Renderer) is
   begin
      Reset (R);
      R.Graphics_State.Transaction.Event_Tracking_Failed := False;
      Free_Rectangles (R.Frame_State.Rectangles);
      Free_Glyphs (R.Frame_State.Glyphs);
      FIS.Release (R.Frame_State.Frame_Images);
      Free_Text_Runs (R.Frame_State.Text_Runs);
      Free_Colour_Glyphs (R.Frame_State.Colour_Glyphs);
      Free_Shaped_Run_Map (R.Frame_State.Shaped_Run_Map);
      for Cache of R.Frame_State.Text_Run_Caches loop
         if Cache.Items /= null then
            for Row of Cache.Items.all loop
               Free_Text_Runs (Row.Runs);
               Free_Rectangles (Row.Rectangles);
               Free_Glyphs (Row.Glyphs);
               Free_Colour_Glyphs (Row.Colour_Glyphs);
            end loop;
            Free_Cached_Rows (Cache.Items);
         end if;
         Cache := (others => <>);
      end loop;
      VS.Release (R.Frame_State.Batch);
   end Release;

   procedure Ensure_Capacity
     (R               : in out Renderer;
      Rectangle_Count : Positive;
      Glyph_Count     : Positive;
      Colour_Count    : Positive;
      Image_Count     : Positive;
      Text_Run_Count  : Positive;
      Map_Cell_Count  : Positive;
      Success         : out Boolean)
   is
   begin
      if R.Frame_State.Rectangles = null
        or else R.Frame_State.Rectangles'Length < Rectangle_Count
      then
         declare
            Replacement : RM.Rectangle_Array_Access :=
              new RM.Rectangle_Array
                (1 .. Grown_Capacity
                  ((if R.Frame_State.Rectangles = null then 0
                    else R.Frame_State.Rectangles'Length), Rectangle_Count));
         begin
            Free_Rectangles (R.Frame_State.Rectangles);
            R.Frame_State.Rectangles := Replacement;
         end;
      end if;
      if R.Frame_State.Glyphs = null
        or else R.Frame_State.Glyphs'Length < Glyph_Count
      then
         declare
            Replacement : RM.Glyph_Array_Access :=
              new RM.Glyph_Array
                (1 .. Grown_Capacity
                  ((if R.Frame_State.Glyphs = null then 0
                    else R.Frame_State.Glyphs'Length), Glyph_Count));
         begin
            Free_Glyphs (R.Frame_State.Glyphs);
            R.Frame_State.Glyphs := Replacement;
         end;
      end if;
      if R.Frame_State.Colour_Glyphs = null
        or else R.Frame_State.Colour_Glyphs'Length < Colour_Count
      then
         declare
            Replacement : RM.Colour_Glyph_Array_Access :=
              new RM.Colour_Glyph_Array
                (1 .. Grown_Capacity
                  ((if R.Frame_State.Colour_Glyphs = null then 0
                    else R.Frame_State.Colour_Glyphs'Length), Colour_Count));
         begin
            Free_Colour_Glyphs (R.Frame_State.Colour_Glyphs);
            R.Frame_State.Colour_Glyphs := Replacement;
         end;
      end if;
      FIS.Ensure_Capacity (R.Frame_State.Frame_Images, Image_Count, Success);
      if not Success then
         return;
      end if;
      if R.Frame_State.Text_Runs = null
        or else R.Frame_State.Text_Runs'Length < Text_Run_Count
      then
         declare
            Replacement : RM.Text_Run_Array_Access :=
              new RM.Text_Run_Array
                (1 .. Grown_Capacity
                  ((if R.Frame_State.Text_Runs = null then 0
                    else R.Frame_State.Text_Runs'Length), Text_Run_Count));
         begin
            Free_Text_Runs (R.Frame_State.Text_Runs);
            R.Frame_State.Text_Runs := Replacement;
         end;
      end if;
      if R.Frame_State.Shaped_Run_Map = null
        or else R.Frame_State.Shaped_Run_Map'Length < Map_Cell_Count
      then
         declare
            Replacement : Shaped_Run_Map_Array_Access :=
              new Shaped_Run_Map_Array
                (1 .. Grown_Capacity
                  ((if R.Frame_State.Shaped_Run_Map = null then 0
                    else R.Frame_State.Shaped_Run_Map'Length), Map_Cell_Count));
         begin
            Free_Shaped_Run_Map (R.Frame_State.Shaped_Run_Map);
            R.Frame_State.Shaped_Run_Map := Replacement;
         end;
      end if;
      Success := True;
   exception
      when Storage_Error =>
         Success := False;
   end Ensure_Capacity;

   procedure Ensure_Rectangle_Capacity
     (R : in out Renderer; Required : Positive; Success : out Boolean) is
   begin
      Success := True;
      if R.Frame_State.Rectangles /= null
        and then R.Frame_State.Rectangles'Length >= Required
      then
         return;
      end if;
      declare
         Replacement : RM.Rectangle_Array_Access := new RM.Rectangle_Array
           (1 .. Grown_Capacity
             ((if R.Frame_State.Rectangles = null then 0
               else R.Frame_State.Rectangles'Length), Required));
      begin
         if R.Frame_State.Rectangle_Count > 0 then
            Replacement (1 .. R.Frame_State.Rectangle_Count) :=
              R.Frame_State.Rectangles (1 .. R.Frame_State.Rectangle_Count);
         end if;
         Free_Rectangles (R.Frame_State.Rectangles);
         R.Frame_State.Rectangles := Replacement;
      end;
   exception
      when Storage_Error => Success := False;
   end Ensure_Rectangle_Capacity;

   procedure Ensure_Glyph_Capacity
     (R : in out Renderer; Required : Positive; Success : out Boolean) is
   begin
      Success := True;
      if R.Frame_State.Glyphs /= null
        and then R.Frame_State.Glyphs'Length >= Required
      then
         return;
      end if;
      declare
         Replacement : RM.Glyph_Array_Access := new RM.Glyph_Array
           (1 .. Grown_Capacity
             ((if R.Frame_State.Glyphs = null then 0
               else R.Frame_State.Glyphs'Length), Required));
      begin
         if R.Frame_State.Glyph_Count > 0 then
            Replacement (1 .. R.Frame_State.Glyph_Count) :=
              R.Frame_State.Glyphs (1 .. R.Frame_State.Glyph_Count);
         end if;
         Free_Glyphs (R.Frame_State.Glyphs);
         R.Frame_State.Glyphs := Replacement;
      end;
   exception
      when Storage_Error => Success := False;
   end Ensure_Glyph_Capacity;

   procedure Ensure_Colour_Capacity
     (R : in out Renderer; Required : Positive; Success : out Boolean) is
   begin
      Success := True;
      if R.Frame_State.Colour_Glyphs /= null
        and then R.Frame_State.Colour_Glyphs'Length >= Required
      then
         return;
      end if;
      declare
         Replacement : RM.Colour_Glyph_Array_Access :=
           new RM.Colour_Glyph_Array
             (1 .. Grown_Capacity
               ((if R.Frame_State.Colour_Glyphs = null then 0
                 else R.Frame_State.Colour_Glyphs'Length), Required));
      begin
         if R.Frame_State.Colour_Glyph_Count > 0 then
            Replacement (1 .. R.Frame_State.Colour_Glyph_Count) :=
              R.Frame_State.Colour_Glyphs
                (1 .. R.Frame_State.Colour_Glyph_Count);
         end if;
         Free_Colour_Glyphs (R.Frame_State.Colour_Glyphs);
         R.Frame_State.Colour_Glyphs := Replacement;
      end;
   exception
      when Storage_Error => Success := False;
   end Ensure_Colour_Capacity;

   procedure Ensure_Text_Run_Capacity
     (R : in out Renderer; Required : Positive; Success : out Boolean) is
   begin
      Success := True;
      if R.Frame_State.Text_Runs /= null
        and then R.Frame_State.Text_Runs'Length >= Required
      then
         return;
      end if;
      declare
         Replacement : RM.Text_Run_Array_Access := new RM.Text_Run_Array
           (1 .. Grown_Capacity
             ((if R.Frame_State.Text_Runs = null then 0
               else R.Frame_State.Text_Runs'Length), Required));
      begin
         if R.Frame_State.Text_Run_Count > 0 then
            Replacement (1 .. R.Frame_State.Text_Run_Count) :=
              R.Frame_State.Text_Runs (1 .. R.Frame_State.Text_Run_Count);
         end if;
         Free_Text_Runs (R.Frame_State.Text_Runs);
         R.Frame_State.Text_Runs := Replacement;
      end;
   exception
      when Storage_Error => Success := False;
   end Ensure_Text_Run_Capacity;

   function Submission_Render_Status
     (Status : VS.Build_Status) return Render_Status is
     (case Status is
         when VS.Ok                => Ok,
         when VS.Invalid_Frame     => Batch_Build_Failed,
         when VS.Capacity_Exceeded => Batch_Build_Failed,
         when VS.Allocation_Failed => Allocation_Failed);

   procedure Begin_Frame
     (Transaction : in out Graphics_Transaction_State;
      Frame       : in out Renderer_Frame_State;
      Cell_Count : Natural;
      Width      : Natural;
      Height     : Natural) is
   begin
      Transaction.Event_Tracking_Failed := False;
      Frame.Last_Cell_Count := Cell_Count;
      Frame.Last_Frame_Width := Width;
      Frame.Last_Frame_Height := Height;
   end Begin_Frame;

   procedure Record_Dirty_Rows
     (Frame    : in out Renderer_Frame_State;
      Snapshot : Terminal.Core.Render_Snapshot) is
   begin
      if Terminal.Core.Has_Dirty_Rows (Snapshot) then
         for Row in 1 .. Snapshot.Rows loop
            if Terminal.Core.Dirty_Row (Snapshot, Row) then
               Frame.Last_Dirty_Rows := Frame.Last_Dirty_Rows + 1;
            end if;
         end loop;
      end if;
   end Record_Dirty_Rows;

   procedure Build_Submission_Batch
     (Commands : Terminal.App.Render_Model.Frame_Commands;
      Text     : in out Renderer_Text_State;
      Frame    : in out Renderer_Frame_State;
      Status : out Render_Status)
   is
      Batch_Status : VS.Build_Status;
   begin
      Text.Atlas_Dirty :=
        Text.Atlas_Dirty or else Textrender.Atlas_Dirty (Text.Text);
      Text.Colour_Sheet_Dirty :=
        Text.Colour_Sheet_Dirty
        or else Textrender.Colour_Sheet_Dirty (Text.Text);

      VS.Build (Commands, Frame.Batch, Batch_Status);
      if Batch_Status /= VS.Ok then
         Status := Submission_Render_Status (Batch_Status);
      else
         Frame.Vertex_Count := VS.Vertex_Count (Frame.Batch);
         Status := Ok;
      end if;
   end Build_Submission_Batch;

   procedure Prepare
     (R               : in out Renderer;
      Cell_Count      : Natural;
      Width           : Natural;
      Height          : Natural;
      Rectangle_Count : Positive;
      Glyph_Count     : Positive;
      Colour_Count    : Positive;
      Image_Count     : Positive;
      Text_Run_Count  : Positive;
      Map_Cell_Count  : Positive;
      Status          : out Render_Status)
   is
      Capacity_Ok : Boolean;
   begin
      Reset (R);
      Begin_Frame
        (R.Graphics_State.Transaction, R.Frame_State,
         Cell_Count, Width, Height);
      Ensure_Capacity
        (R, Rectangle_Count, Glyph_Count, Colour_Count, Image_Count,
         Text_Run_Count, Map_Cell_Count, Capacity_Ok);
      if not Capacity_Ok then
         Release (R);
         R.Lifecycle.Last_Render_Status := Allocation_Failed;
         Status := Allocation_Failed;
         return;
      end if;
      Terminal.App.Renderer.Animations.Advance (R);
      Status := Ok;
   end Prepare;

   procedure Record_Dirty_Rows
     (R        : in out Renderer;
      Snapshot : Terminal.Core.Render_Snapshot) is
   begin
      Record_Dirty_Rows (R.Frame_State, Snapshot);
   end Record_Dirty_Rows;

   procedure Finish (R : in out Renderer; Status : out Render_Status) is
   begin
      if R.Frame_State.Frame_Command_Overflowed then
         Release (R);
         Status := Allocation_Failed;
      else
         Build_Submission_Batch
           (Last_Frame (R), R.Text_State, R.Frame_State, Status);
      end if;
      R.Lifecycle.Last_Render_Status := Status;
   end Finish;
end Terminal.App.Renderer.Frame_Lifecycle;
