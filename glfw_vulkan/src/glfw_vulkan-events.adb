with Interfaces.C;
with GLFW_Vulkan.Raw;

package body GLFW_Vulkan.Events is
   procedure Poll is
   begin
      Raw.Poll_Events;
   end Poll;

   procedure Wait is
   begin
      Raw.Wait_Events;
   end Wait;

   procedure Wait_Timeout (Seconds : Duration) is
   begin
      Raw.Wait_Events_Timeout (Interfaces.C.double (Seconds));
   end Wait_Timeout;

   procedure Post_Empty_Event is
   begin
      Raw.Post_Empty_Event;
   end Post_Empty_Event;
end GLFW_Vulkan.Events;

