with Terminal.Core;

package Terminal.App.Screen_Text is
   --  Return the visible grid as UTF-8, trimming trailing empty cells on each
   --  row.  At most Max_Bytes are returned; truncation always happens between
   --  complete UTF-8 clusters.
   function Visible
     (Snapshot  : Terminal.Core.Render_Snapshot;
      Max_Bytes : Natural := Natural'Last) return String;
end Terminal.App.Screen_Text;
