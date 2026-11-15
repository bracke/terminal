private package Terminal.Core.Snapshot_Access is
   procedure Release (S : in out Render_Snapshot);

   function Cell_Count (S : Render_Snapshot) return Natural;
   function Image_Cell_Count (S : Render_Snapshot) return Natural;
   function Blinking_Cell_Count (S : Render_Snapshot) return Natural;
   function Is_Valid (S : Render_Snapshot) return Boolean;
   function Rows (S : Render_Snapshot) return Natural;
   function Cols (S : Render_Snapshot) return Natural;
   function Graphics_Stream
     (S : Render_Snapshot) return Graphics_Stream_ID;
   function Graphics_Transaction
     (S : Render_Snapshot) return Graphics_Transaction_Generation;
   function Alternate_Screen (S : Render_Snapshot) return Boolean;
   function Screen_Generation
     (S : Render_Snapshot) return Graphics_Screen_Generation;
   function Scrollback_Offset (S : Render_Snapshot) return Natural;
   function Scrollback_Rows (S : Render_Snapshot) return Natural;
   function Graphics_Scroll_Current
     (S : Render_Snapshot) return Graphics_Scroll_Sequence;
   function Graphics_Scroll_Oldest
     (S : Render_Snapshot) return Graphics_Scroll_Sequence;
   function Graphics_Scroll_Count (S : Render_Snapshot) return Natural;
   function Cursor (S : Render_Snapshot) return Cursor_State;
   function Graphics (S : Render_Snapshot) return Graphics_Event;

   function Cell_At_Index
     (S : Render_Snapshot; Index : Positive) return Cell;
   function Cell_At
     (S   : Render_Snapshot;
      Row : Positive;
      Col : Positive) return Cell;
   function Cell_Content_At
     (S   : Render_Snapshot;
      Row : Positive;
      Col : Positive) return Cell_Content;
   function Cell_Link_Equals
     (S     : Render_Snapshot;
      Row   : Positive;
      Col   : Positive;
      Value : Hyperlink) return Boolean;
   function Cell_Kind_At
     (S   : Render_Snapshot;
      Row : Positive;
      Col : Positive) return Cell_Kind;
   function Cell_Text_At
     (S   : Render_Snapshot;
      Row : Positive;
      Col : Positive) return Text_Cluster;
   function Cell_Style_At_Index
     (S : Render_Snapshot; Index : Positive) return Cell_Style;

   function Has_Dirty_Rows (S : Render_Snapshot) return Boolean;
   function Dirty_Row
     (S : Render_Snapshot; Row : Positive) return Boolean;
   function Has_Graphics_Scroll_Events
     (S : Render_Snapshot) return Boolean;
   function Graphics_Scroll_Event_At
     (S : Render_Snapshot; Index : Positive) return Graphics_Scroll_Event;

   procedure Set_Cell
     (S     : in out Render_Snapshot;
      Index : Positive;
      Value : Cell);
   procedure Replace_All_Cells
     (S           : in out Render_Snapshot;
      Value_At    : not null access function
        (Index : Positive) return Cell);
   procedure Set_Cell_Deferred
     (S     : in out Render_Snapshot;
      Index : Positive;
      Value : Cell);
   procedure Set_Compact_Cell
     (S     : in out Render_Snapshot;
      Index : Positive;
      Value : Snapshot_Cell);
   procedure Set_Cell_Style
     (S     : in out Render_Snapshot;
      Index : Positive;
      Value : Cell_Style);
   procedure Set_Dirty_Row
     (S     : in out Render_Snapshot;
      Row   : Positive;
      Value : Boolean);
end Terminal.Core.Snapshot_Access;
