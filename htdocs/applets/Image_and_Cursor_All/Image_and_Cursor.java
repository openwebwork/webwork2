//
//  Image_and_Cursor.java
//
//  Written by Frank Wattenberg
//
//  Version 0.40
//  6 June 2002
//
//  Uses new parser written by Darius Bacon
//
//  Known problems
//
//  Lines drawn with a slope of -1 seem to be off by one pixel.   
//

import java.awt.*;
import java.applet.*;
import java.util.*;
import java.io.*;                // for Expr class
import java.util.Hashtable;      // for Variable class
import java.util.Vector;

public class Image_and_Cursor extends Applet 
{
       int          check_out_sw = 1;                      // 0 = omit console messages; 1 = write console messages
              
       int          margin_x, margin_y;                    // Left and right margins (pixels)
       int          mid_x, mid_y;                          // Location of cursor control points
       int          cursor_size;                           // Size of cursor
       
       int          cursor_pad_sw;                         // 0 = cursors at edges, 1 = cursor pad
       int          cursor_pad_x, cursor_pad_y;            // Center of cursor pad if pad
       
       Color        controls_color;                        // Color for cursor controls
       Color        cursor_color;
       Color        back_color;                            // Background color
       Color        button_color;
       Color        shadow_color;                          // Button shadow color
       Color        list_color;                            // List button color
       Color        list_shadow_color;                     // List button shadow color
       Color        mark_color;                            // Color for mark symbols
       int          mark_sw;                               // 0 = no marks, 1 = squares, 2 = filled squares, 
                                                           // 3 = diamonds, 4 = filled diamonds
       int          mark_radius;                           // Controls size (radius) of mark symbols
       int          mark_connect;                          // 0 = do not connect marks by lines; 1 = do connect marks by lines
       Color        clear_color;                           // Clear button color
       Color        clear_shadow_color;                    // Clear button shadow color
       
       VCRButton    record_button;                         // Press this button to record one point
       VCRButton    list_button;                           // Press this button to list recorded data
       VCRButton    clear_button;                          // Press this button to clear recorded data
       
       int          font_size;                             // Size of display font
       Font         text_font;
       int          display_placement;                     // 0 = underneath, 1 = at right
       int          coordinates_left;                      // left edge of coordinate display
       int          coordinates_top;                       // top of coordinate display
       int          button_left;                           // left edge for buttons
       int          button_top;                            // top for buttons
       int          button_width;                          // width of buttons
       int          button_height;                         // height of buttons
       int          display_sw;                            // 0 = coordinates only, 1 = coordinates and three buttons, 2 = omit list button
       int          record_sw = 0;                         // 0 = this point not yet recorded; 1 = this point recorded
       
       Graphics     bG;                                    // Screen buffer
       Image        bI;
       
       int          applet_width, applet_height;           // Applet dimensions
       int          image_width, image_height;             // Image dimensions
       
       int          cursor_x, cursor_y;                    // Cursor coordinates (pixels)
       
       Image        backdrop;                              // backdrop image
       String       backdrop_filename;
       
       int          save_x[] = new int[1000];              // Save the x-and y-coordinates of marked points
       int          save_y[] = new int[1000];
       String       save_distance[] = new String[1000];    // Save the polar coordinates of marked points as
       String       save_angle[] = new String[1000];       // formatted strings
       double       angle, distance;
       int          save_index = 0;
                                                
       DataDisplayFrame       list_window;                 // Window for list of marked points
       DataDisplayFrame       message_window;              // Window for parser error messages.
       
       Expr         x_of_t;                                // The expression for x(t)
       Expr         y_of_t;                                // The expression for y(t)
       Expr         y_of_x;                                // The expression for y(x)
       Expr         r_of_theta;                            // The expression for r(theta)
       Expr         curve_a_expression;                    // Expression for curve_a
       Expr         curve_b_expression;                    // Expression for curve_b
       
       String       recovery_message_line_1;               // Recovery message printed for syntax errors
       String       recovery_message_line_2;

       Variable     t     = Variable.make("t");            // independent variable for parametric curve
       Variable     x     = Variable.make("x");            // independent variable for y = f(x) curve
       Variable     theta = Variable.make("theta");        // Independent variable for curve in polar coordinates
       Variable     Picon = Variable.make("Pi");           // define Pi, pi, E, and e
       Variable     PIcon = Variable.make("PI");
       Variable     picon = Variable.make("pi");
       Variable     Econ  = Variable.make("E");
       Variable     econ  = Variable.make("e");
       
       int          curve_n;                               // number of steps for parametric curve
       String       curve_a_string;                        // expression for curve_a
       String       curve_b_string;                        // expression for curve_b
       double       curve_a;                               // left (t) end point for parametric curve
       double       curve_b;                               // right (t) end point for parametric curve
       double       curve_dt;                              // step size for parametric curve
       double       curve_t;
       String       curve_x_of_t;
       String       curve_y_of_t;
       String       curve_y_of_x;
       String       curve_r_of_theta;
       int          curve_sw;                              // 0 = no curve; 1 = y = f(x) curve; 2 = parametric curve; 3 = curve in polar coordinates
       int          curve_thickness;                       // thickness is 2 * curve_thickness + 1
       Color        curve_color;
       int          x_start, y_start, x_end, y_end;        // used to draw curve 
       
       int          cas_sw;                                // 0 = Maple; 1 = Mathematica; 2 = MathCAD/Spreadsheet
       
       int          polar_sw;                              // 0 = Cartesian; 1 = polar in radians; 2 = polar in degrees
       Color        polar_color;
       int          polar_origin_x, polar_origin_y;
       
       int          grid_sw, grid_x_start, grid_dx, grid_y_start, grid_dy, grid_width, grid_height, grid_fill_sw;
       Color        grid_color;
       
       public String formatdouble(double arg, int width, int digits)
       {
           double   work;
           int      iwork;
           String   swork;
           String   blanks = "                                             ";
           String   zeros  = "000000000000000000000000000000000000000000000";

           work = arg;
           for(int i = 0; i < digits; i = i + 1)
               work = 10 * work;
           iwork = (int) java.lang.Math.round(work);
           swork = java.lang.Integer.toString(iwork);
           iwork = swork.length();
           if (iwork < digits)
           {
               swork = zeros.substring(0, digits - iwork + 1) + swork;
               iwork = swork.length();
           }
           swork = swork.substring(0, iwork - digits) + "." + swork.substring(iwork - digits, iwork);
           iwork = swork.length();
           swork = blanks.substring(0, width - iwork) + swork;
           return swork;
       }
       
       public int getInteger(String param_name, int low, int high, int no_param)
       {
           int    value;
           if (check_out_sw == 1)
           {
               System.out.println("Parameter: " + param_name);
               System.out.println("    Default value: " + java.lang.Integer.toString(no_param));           
           }
           if (getParameter(param_name) != null)
           {
               value = Integer.parseInt(getParameter(param_name));
               value = java.lang.Math.min(high, java.lang.Math.max(low, value));
           }
           else
           {
               value = no_param;
           }
           if (check_out_sw == 1)
           {
               System.out.println("     Actual value: " + java.lang.Integer.toString(value));           
           }
           return value;
       }
       
       public String getString(String param_name, String no_param)
       {
           String     value;
           
           if (check_out_sw == 1)
           {
               System.out.println("Parameter: " + param_name);
               System.out.println("    Default value: " + no_param);           
           }
           if (getParameter(param_name) != null)
           {
               value = getParameter(param_name);      
           }
           else
           {
               value = no_param;
           }
           if (check_out_sw == 1)
           {
               System.out.println("     Actual value: " + value);           
           }
           return value;
       }
       
       public double getDouble(String param_name, double low, double high, double no_param)
       {
           double    value;
           if (check_out_sw == 1)
           {
               System.out.println("Parameter: " + param_name);
               System.out.println("    Default value: " +  java.lang.Double.toString(no_param));           
           }
           if (getParameter(param_name) != null)
           {
               value = java.lang.Double.valueOf(getParameter(param_name)).doubleValue();
               value = java.lang.Math.min(high, java.lang.Math.max(low, value));
           }
           else
           {
               value = no_param;
           }
           if (check_out_sw == 1)
           {
               System.out.println("     Actual value: " + java.lang.Double.toString(value));           
           }
           return value;
       }

       public Color getColor(String color_parameter, String default_color_parameter)
       {
            int    red, green, blue;
            Color  color_variable;
            String work;
            
            work   = getString(color_parameter, default_color_parameter);
            if (work.length() != 9)
                work = default_color_parameter;
            red = Integer.parseInt(work.substring(0, 3));
            green = Integer.parseInt(work.substring(3, 6));
            blue = Integer.parseInt(work.substring(6, 9));
            red = java.lang.Math.max(0, java.lang.Math.min(255, red));
            green = java.lang.Math.max(0, java.lang.Math.min(255, green));
            blue = java.lang.Math.max(0, java.lang.Math.min(255, blue));
            color_variable = new Color(red, green, blue);
            return color_variable;       
       }
       
        public void init()
       {
           check_out_sw = getInteger("check_out_sw", 0, 1, 0);
           
           if (check_out_sw == 1)
           {
               System.out.println("Starting Image_and_Cursor Applet.");
               System.out.println("Parameter messages to follow.");                
           }
           else
           {
               System.out.println("Starting Color_Play Applet.");
               System.out.println("Parameter messages omitted."); 
               System.out.println("To turn parameter messages on add an");
               System.out.println("applet parameter tag setting check_out_sw to 1.");               
           }
		
           applet_width = getInteger("applet_width", 100, 2000, 100);    // Get applet dimensions
           
           applet_height = getInteger("applet_height", 100, 2000, 100);
           
           bI = createImage(applet_width, applet_height);                // Screen buffer
           bG = bI.getGraphics();
           
           image_width = getInteger("image_width", 10, 2000, 10);        // Get (backdrop) image dimensions
           image_height = getInteger("image_height", 10, 2000, 10);
           margin_x = getInteger("margin_x", 0, applet_width - image_width, (applet_width - image_width)/2);
           margin_y = getInteger("margin_y", 0, applet_height - image_height, (applet_height - image_height)/2); 
           
           backdrop_filename = getString("backdrop_filename", "No file name parameter");
           backdrop = getImage(getCodeBase(), backdrop_filename);        // Backdrop image
           back_color = getColor("back_color", "255255255");
           
           cursor_color = getColor("cursor_color", "000000000");
           cursor_x = getInteger("cursor_x", 0, image_width - 1, image_width/2);
           cursor_y = image_height - 1 - getInteger("cursor_y", 0, image_height - 1, image_height/2);
           
           cursor_pad_sw = getInteger("cursor_pad_sw", 0, 1, 0);
           cursor_pad_x = getInteger("cursor_pad_x", 0, applet_width, margin_x + image_width + 150);
           cursor_pad_y = getInteger("cursor_pad_y", 0, applet_height, margin_y + image_height/2);
           
           controls_color = getColor("controls_color", "000000000");
           
           mid_x = margin_x + image_width/2;
           mid_y = margin_y + image_height/2;
           
           cursor_size = getInteger("cursor_size", 5, 40, 10);
           font_size = getInteger("font_size", 8, 48, 12);               // Set font for display
           text_font = new Font("Courier", Font.BOLD, font_size);
           bG.setFont(text_font);

           display_placement = getInteger("display_placement", 0, 1, 0); // Display placement          
           if (display_placement == 0)
           {
               // Set up for display underneath image
               //
               coordinates_left = getInteger("coordinates_left", 0, applet_width, margin_x);
               button_left = getInteger("button_left", 0, applet_width, margin_x + image_width/2);
               coordinates_top = getInteger("coordinates_top", margin_y + image_height + 5, applet_height, 
                                            margin_y + image_height + cursor_size + 15); 
               button_top = getInteger("button_top", margin_y + image_height + 5, applet_height,
                                    margin_y + image_height + cursor_size + 15);
           }
           else
           {
               // Set up for display to the right of the image
               //
               coordinates_left = getInteger("coordinates_left", 0, applet_width, margin_x + image_width + cursor_size + 15);
               button_left = getInteger("button_left", 0, applet_width, margin_x + image_width + cursor_size + 15);
               coordinates_top = getInteger("coordinates_top", 0, applet_height, margin_y);
               button_top = getInteger("button_top", 0, applet_height, margin_y + image_height/2);          
           }           
           display_sw = getInteger("display_sw", 0, 2, 1);
           
           button_color = getColor("button_color", "064064255");
           button_width = getInteger("button_width", 10, 200, 80);
           button_height = getInteger("button_height", 10, 50, 20);
           
           shadow_color = getColor("shadow_color", "000000128");
           
           record_button = new VCRButton(button_left, button_top, button_width, button_height, 
                                         button_color, back_color, shadow_color, "Mark point");
                                         
           list_color = getColor("list_color", "255064064");
           
           list_shadow_color = getColor("list_shadow_color", "128000000");
           
           list_button = new VCRButton(button_left, button_top + 2 * button_height, button_width, button_height,
                                         list_color, back_color, list_shadow_color, "List points");
                                         
           clear_color = getColor("clear_color", "064064064");
           clear_shadow_color = getColor("clear_shadow_color", "000000000");
           
           clear_button = new VCRButton(button_left, button_top + 4 * button_height, button_width, button_height,
                                           clear_color, back_color, clear_shadow_color, "Clear points"); 
                                         
           mark_color = getColor("mark_color", "000000000");
           mark_sw = getInteger("mark_sw", 0, 4, 4);
           mark_radius = getInteger("mark_radius", 0, 10, 3);
           mark_connect = getInteger("mark_connect", 0, 1, 0);
                                         
           picon.set_value(Math.PI);
           Picon.set_value(Math.PI);
           PIcon.set_value(Math.PI);
           econ.set_value(Math.E);   
           Econ.set_value(Math.E);
           
           recovery_message_line_1 = getString("recovery_message_line_1", "Close this window and the previous window.");
           recovery_message_line_2 = getString("recovery_message_line_2", "");
           
           curve_n = getInteger("curve_n", 10, 1000, 100);
           curve_x_of_t = getString("curve_x_of_t", "t");
           curve_y_of_t = getString("curve_y_of_t", "t");
           curve_y_of_x = getString("curve_y_of_x", "x");
           curve_a_string = getString("curve_a", "0");
           curve_b_string = getString("curve_b", "1");
           curve_r_of_theta = getString("r_of_theta", "theta");
           
           try
           {
               curve_a_expression = Parser.parse(curve_a_string);
           }
           catch (SyntaxException e)
           {
               tell_error("Syntax error: " + e + "\n" + e.explain());
               return;
           }
           
           try
           {
               curve_b_expression = Parser.parse(curve_b_string);
           }
           catch (SyntaxException e)
           {
               tell_error("Syntax error: " + e + "\n" + e.explain());
               return;
           }
           
           curve_a = curve_a_expression.value();
           curve_b = curve_b_expression.value();
           curve_dt = (curve_b - curve_a)/curve_n;
           curve_sw = getInteger("curve_sw", 0, 3, 0);
           curve_thickness = getInteger("curve_thickness", 0, 10, 1);
           
           try
           {
               x_of_t = Parser.parse(curve_x_of_t);
           }
           catch (SyntaxException e)
           {
               tell_error("Syntax error: " + e + "\n" + e.explain());
               return;
           }
   
           try
           {
               y_of_t = Parser.parse(curve_y_of_t);
           }
           catch (SyntaxException e)
           {
               tell_error("Syntax error: " + e + "\n" + e.explain());
               return;
           }

           try
           {
               y_of_x = Parser.parse(curve_y_of_x);
           }
           catch (SyntaxException e)
           {
               tell_error("Syntax error: " + e + "\n" + e.explain());
               return;
           }

           try
           {
               r_of_theta = Parser.parse(curve_r_of_theta);
           }
           catch (SyntaxException e)
           {
               tell_error("Syntax error: " + e + "\n" + e.explain());
               return;
           }

           curve_color = getColor("curve_color", "000000000");
           
           cas_sw = getInteger("cas_sw", 0, 2, 2);
           
           polar_sw = getInteger("polar_sw", 0, 2, 0);
           if (polar_sw > 0)
           {
               polar_color = getColor("polar_color", "255255255");
               polar_origin_x = getInteger("polar_origin_x", 0, image_width - 1, image_width/2);
               polar_origin_y = getInteger("polar_origin_y", 0, image_height - 1, image_height/2);
           }
           
           grid_sw = getInteger("grid_sw", 0, 1, 0);
           grid_x_start = getInteger("grid_x_start", 0, image_width - 1, 0);
           grid_dx = getInteger("grid_dx", 2, image_width - 1, 10);
           grid_y_start = getInteger("grid_y_start", 0, image_height - 1, 0);
           grid_dy = getInteger("grid_dy", 1, image_height - 1, 10);
           grid_color = getColor("grid_color", "000000000");
           grid_width = getInteger("grid_width", 0, image_width, image_width);
           grid_height = getInteger("grid_height", 0, image_height, image_height);
           grid_fill_sw = getInteger("grid_fill_sw", 0, 1, 0);
       }
       
       public void paint(Graphics g)
       {
           super.paint(g);
           drawcursors();
           g.drawImage(bI, 0, 0, this);       
       }
       
       public void update(Graphics g)
       {
           paint(g);       
       }

       public void drawcursors()
       {
           int work, work_x, work_y;
           int center_x, center_y;
           int real_y;
           String angle_string;
           
           bG.setColor(back_color);
           bG.fillRect(0, 0, applet_width, applet_height);
           bG.drawImage(backdrop, margin_x, margin_y, this);
           
           if(grid_sw == 1)
           {
              bG.setColor(grid_color);
              for (int ix = grid_x_start; ix <= grid_x_start + grid_width - 1; ix = ix + grid_dx)
              {
                   bG.drawLine(margin_x + ix, margin_y + image_height - 1 - grid_y_start, 
                               margin_x + ix, margin_y + image_height - grid_y_start - grid_height);
              }
              for (int iy = grid_y_start; iy <= grid_y_start + grid_height - 1; iy = iy + grid_dy)
              {
                   bG.drawLine(margin_x + grid_x_start, margin_y + image_height - 1 - iy, 
                               margin_x + grid_x_start + grid_width - 1, margin_y + image_height - 1 - iy);
              }
           }
           
           if (polar_sw > 0)
           {
           
               //  Draw polar grid
               
               bG.setColor(polar_color);
               
               //  Compute center for diagonal polar grid lines
               
               center_x = margin_x + polar_origin_x;
               center_y = margin_y + image_height - 1 - polar_origin_y;
               
               //  Draw horizontal and vertical polar grid lines
               
               bG.drawLine(margin_x, center_y, margin_x + image_width - 1, center_y);
               bG.drawLine(center_x, margin_y, center_x, margin_y + image_height - 1);
               
               //  Draw 45 degree polar grid line
               
               work = java.lang.Math.min(image_width - 1 - polar_origin_x, polar_origin_y) + 1;
               bG.drawLine(center_x, center_y, center_x + work, center_y + work);
               
               //  Draw -45 degree polar grid line
               
               work = java.lang.Math.min(image_width - polar_origin_x, image_height - polar_origin_y) + 1;               
               bG.drawLine(center_x, center_y, center_x + work, center_y - work);
               
               //  Draw 135 degree polar grid line
               
               work = java.lang.Math.min(polar_origin_x, polar_origin_y) + 1;
               bG.drawLine(center_x, center_y, center_x - work, center_y + work);
               
               //  Draw -135 degree polar grid line
                 
               work = java.lang.Math.min(polar_origin_x, image_height - 1 - polar_origin_y);
               bG.drawLine(center_x, center_y, center_x - work, center_y - work);               
           }
           
           //  Draw control buttons
           
           if (record_sw == 0)
           {
               if (display_sw > 0)
               {
                   record_button.draw_off(bG);          
                   if (save_index > 0)
                   {
                       clear_button.draw_off(bG);
                       if (display_sw == 1)
                           list_button.draw_off(bG);
                   }
                   else
                   {
                       clear_button.draw_on(bG);
                       if (display_sw == 1)                   
                           list_button.draw_on(bG);
                   }
               }
           }
           else
           {
               if (display_sw > 0)
               {
                   record_button.draw_on(bG);
                   if (display_sw == 1)          
                       list_button.draw_off(bG);
                   if (save_index > 0)
                   {
                       clear_button.draw_off(bG);
                   }
                   else
                   {
                       clear_button.draw_on(bG);                   
                   }
               }
           }
           
           //  Draw marks at recorded points
        
           if ((mark_sw > 0) & (grid_fill_sw == 0))
           {
               bG.setColor(mark_color);
               for (int i = 0; i < save_index; i = i + 1)
               {
                   work_x = margin_x + save_x[i];                        // x- and y-coordinates of marked point
                   work_y = margin_y + image_height - save_y[i] - 1;
               
                   if (mark_sw == 1)    // Mark by open box
                   {
                        bG.drawLine(work_x - mark_radius, work_y + mark_radius, work_x + mark_radius, work_y + mark_radius); 
                        bG.drawLine(work_x - mark_radius, work_y - mark_radius, work_x + mark_radius, work_y - mark_radius); 
                        bG.drawLine(work_x - mark_radius, work_y - mark_radius, work_x - mark_radius, work_y + mark_radius); 
                        bG.drawLine(work_x + mark_radius, work_y - mark_radius, work_x + mark_radius, work_y + mark_radius); 
                   }
               
                   if (mark_sw == 2)    // Mark by solid box
                   {
                        for (int j = -mark_radius; j <= mark_radius; j = j + 1)
                             bG.drawLine(work_x - mark_radius, work_y + j, work_x + mark_radius, work_y + j); 
                   }
               
                   if (mark_sw == 3)    // Mark by open diamond
                   {
                       bG.drawLine(work_x - mark_radius, work_y, work_x, work_y + mark_radius); 
                       bG.drawLine(work_x, work_y + mark_radius, work_x + mark_radius, work_y); 
                       bG.drawLine(work_x + mark_radius, work_y, work_x, work_y - mark_radius); 
                       bG.drawLine(work_x, work_y - mark_radius, work_x - mark_radius, work_y); 
                   }
               
                   if (mark_sw == 4)    // Mark by solid diamond (default)
                   {
                       for (int j = 0; j <= mark_radius; j = j + 1)
                       {
                             bG.drawLine(work_x - mark_radius + j, work_y + j, work_x + mark_radius - j, work_y + j); 
                             bG.drawLine(work_x - mark_radius + j, work_y - j, work_x + mark_radius - j, work_y - j);
                       }
                   }
               }
           }
           
           //  Draw lines connecting marked points
           
           if ((mark_sw > 0) & (mark_connect == 1) & (grid_fill_sw == 0))
           {
               bG.setColor(mark_color);
               x_start = margin_x + save_x[0];
               y_start = margin_y + image_height - save_y[0] - 1;
               for (int i = 1; i < save_index; i = i + 1)
               {
                    work_x = margin_x + save_x[i];
                    work_y = margin_y + image_height - save_y[i] - 1;
                    bG.drawLine(x_start, y_start, work_x, work_y);
                    x_start = work_x;
                    y_start = work_y;
               }
           }
           
           if ((grid_fill_sw == 1) & (grid_sw == 1))
           {
               bG.setColor(mark_color);
               for (int i = 0; i < save_index; i = i + 1)
               {
                    work_x = (int) java.lang.Math.floor((save_x[i] - grid_x_start + 100 * grid_dx)/grid_dx) - 100;
                    work_x = grid_x_start + grid_dx * work_x;
                    work_y = (int) java.lang.Math.floor((save_y[i] - grid_y_start + 100 * grid_dy)/grid_dy) - 100;
                    work_y = grid_y_start + grid_dy * work_y + grid_dy;
                    bG.fillRect(margin_x + work_x + 1, margin_y + image_height - work_y, grid_dx - 1, grid_dy - 1);
               }
           }
           
           if (curve_sw == 1)     // Draw curve specified as y(x)
           {
               curve_t = curve_a;
               x.set_value(curve_a);
               bG.setColor(curve_color);
               x_start = (int) java.lang.Math.round(curve_a);
               y_start = (int) java.lang.Math.round(y_of_x.value());
               for (int i = 1; i <= curve_n; i = i + 1)
               {
                    curve_t = curve_t + curve_dt;
                    x.set_value(curve_t);
                    x_end = (int) java.lang.Math.round(curve_t);
                    y_end = (int) java.lang.Math.round(y_of_x.value());      
                    for (int j = -curve_thickness; j <= curve_thickness; j = j + 1)
                    {
                         for (int k = -curve_thickness; k <= curve_thickness; k = k + 1)
                         {
                              bG.drawLine(margin_x + x_start + j,
                                          margin_y + image_height - 1 - y_start + k,
                                          margin_x + x_end + j,
                                          margin_y + image_height - 1 - y_end + k);
                         }
                    }
                    x_start = x_end;
                    y_start = y_end;
               }
           }
           
           if (curve_sw == 2)     // Draw curve specified as x(t), y(t)
           {
               curve_t = curve_a;
               t.set_value(curve_a); 
               bG.setColor(curve_color);
               x_start = (int) java.lang.Math.round(x_of_t.value());
               y_start = (int) java.lang.Math.round(y_of_t.value());
               for (int i = 1; i <= curve_n; i = i + 1)
               {
                    curve_t = curve_t + curve_dt;
                    t.set_value(curve_t);
                    x_end = (int) java.lang.Math.round(x_of_t.value()); 
                    y_end = (int) java.lang.Math.round(y_of_t.value());
                    for (int j = -curve_thickness; j <= curve_thickness; j = j + 1)
                    {
                         for (int k = -curve_thickness; k <= curve_thickness; k = k + 1)
                         {
                              bG.drawLine(margin_x + x_start + j,
                                          margin_y + image_height - 1 - y_start + k,
                                          margin_x + x_end + j,
                                          margin_y + image_height - 1 - y_end + k);
                         }
                    }
                    x_start = x_end;
                    y_start = y_end;
               }
           }
           
           if ((curve_sw == 3) & (polar_sw > 0))
           {
                center_x = margin_x + polar_origin_x;
                center_y = margin_y + image_height - 1 - polar_origin_y;

                curve_t = curve_a;
                t.set_value(curve_t);
                theta.set_value(curve_t);
                bG.setColor(curve_color);
                x_start = (int) java.lang.Math.round(
                                center_x + java.lang.Math.cos(curve_t) * r_of_theta.value());
                y_start = (int) java.lang.Math.round(
                                center_y - java.lang.Math.sin(curve_t) * r_of_theta.value());
                for (int i = 1; i <= curve_n; i = i + 1)
                {
                     curve_t = curve_t + curve_dt;
                     t.set_value(curve_t);
                     theta.set_value(curve_t);
                     x_end = (int) java.lang.Math.round(
                                   center_x + java.lang.Math.cos(curve_t) * r_of_theta.value());
                     y_end = (int) java.lang.Math.round(
                                   center_y - java.lang.Math.sin(curve_t) * r_of_theta.value());
                     for (int j = -curve_thickness; j <= curve_thickness; j = j + 1)
                     {
                          for (int k = -curve_thickness; k <= curve_thickness; k = k + 1)
                               bG.drawLine(x_start + j, y_start + k, x_end + j, y_end + k);
                     }
                     x_start = x_end;
                     y_start = y_end;
               }
           }
           
           //  Draw cursors
           
           bG.setColor(cursor_color);
           bG.drawLine(margin_x + cursor_x, margin_y, margin_x + cursor_x, margin_y + image_height - 1);
           bG.drawLine(margin_x, margin_y + cursor_y, margin_x + image_width - 1, margin_y + cursor_y);
           
           //  Draw controls to move cursor one pixel at a time
           
           bG.setColor(controls_color); 
           for (int i = 0; i <= cursor_size; i = i + 1)
           {
                if (cursor_pad_sw == 0)
                {
                    bG.drawLine(mid_x - i, margin_y - 10 - cursor_size + i, mid_x + i, margin_y - 10 - cursor_size + i);
                    bG.drawLine(mid_x - i, margin_y + 10 + image_height + cursor_size - i, 
                                mid_x + i, margin_y + 10 + image_height + cursor_size - i);
                    bG.drawLine(margin_x - 10 - cursor_size + i, mid_y - i, margin_x - 10 - cursor_size + i, mid_y + i);
                    bG.drawLine(margin_x + image_width + 10 + cursor_size - i, mid_y - i,
                                margin_x + image_width + 10 + cursor_size - i, mid_y + i);
                }
                else
                {
                    bG.drawLine(cursor_pad_x - i, 5 + cursor_pad_y + 10 + cursor_size - i,
                                cursor_pad_x + i, 5 + cursor_pad_y + 10 + cursor_size - i);
                    bG.drawLine(cursor_pad_x - i, cursor_pad_y - 10 - cursor_size + i - 5,
                                cursor_pad_x + i, cursor_pad_y - 10 - cursor_size + i - 5);
                    bG.drawLine(5 + cursor_pad_x + 10 + cursor_size - i, cursor_pad_y - i,
                                5 + cursor_pad_x + 10 + cursor_size - i, cursor_pad_y + i);
                    bG.drawLine(cursor_pad_x - 10 - cursor_size + i - 5, cursor_pad_y - i,
                                cursor_pad_x - 10 - cursor_size + i - 5, cursor_pad_y + i);
                }
           }
           
           //    Print cursor coordinates
           
           bG.drawString("x: " + String.valueOf(cursor_x), coordinates_left, coordinates_top + font_size);
           bG.drawString("y: " + String.valueOf(image_height - cursor_y - 1), coordinates_left, 
                         coordinates_top + 2 * font_size + 5);
           if (grid_fill_sw == 1)
               bG.drawString("count: " + String.valueOf(save_index), coordinates_left, coordinates_top + 3 * font_size + 10);
           if (polar_sw > 0)
           {
               real_y = image_height - cursor_y - 1;
               distance = java.lang.Math.sqrt((cursor_x - polar_origin_x) * (cursor_x - polar_origin_x) +
                                                (real_y - polar_origin_y) * (real_y - polar_origin_y));
               bG.drawString("r: " + formatdouble(distance, 7, 2), 
                              coordinates_left, coordinates_top + 3 * font_size + 10);
               if (cursor_x == polar_origin_x)
               {
                   if (polar_sw == 1)
                   {
                       if (real_y >= polar_origin_y)
                           angle_string = " 1.5708";
                       else
                           angle_string = " 4.7124";
                       if (real_y == polar_origin_y)
                           angle_string = " undefined";
                   }
                   else
                   {
                       if (real_y >= polar_origin_y)
                           angle_string = " 90.00";
                       else
                           angle_string = " 270.00";
                       if (real_y == polar_origin_y)
                           angle_string = " undefined";
                   }
               }
               else
               {
                  angle = java.lang.Math.atan(1.0 * (real_y - polar_origin_y)/(cursor_x - polar_origin_x));
                  if (cursor_x < polar_origin_x)
                      angle = Math.PI + angle;
                  if (angle < 0)
                      angle = angle + 2 * Math.PI;
                  if (polar_sw == 2)
                  {
                      angle = angle * 360 / (2 * Math.PI);
                      angle_string = formatdouble(angle, 10, 2);
                  }
                  else
                      angle_string = formatdouble(angle, 7, 4);
               }
               bG.drawString("theta: " + angle_string, coordinates_left, coordinates_top + 4 * font_size + 15);
           }
       }
       
       public boolean mouseDown(Event evt, int mx, int my)
       {
            int x_start, y_start, x_end, y_end;
            int real_y;
            double work;
            
            if ((mx >= margin_x) & (mx <= margin_x + image_width - 1) & 
                (my >= margin_y) & (my <= margin_y + image_height - 1))
            {
                 cursor_x = mx - margin_x;
                 cursor_y = my - margin_y;
                 record_sw = 0;
                 repaint();
                 return true;
            }
            
            if (cursor_pad_sw == 0)
            {
                 if ((mx >= margin_x - 10 - cursor_size) & (mx <= margin_x - 10) &
                     (my >= mid_y - cursor_size) & (my <= mid_y + cursor_size))
                 {
                      cursor_x = java.lang.Math.max(0, cursor_x - 1);
                      record_sw = 0;
                      repaint();
                      return true; 
                 }
                 if ((mx >= margin_x + image_width + 10) & (mx <= margin_x + image_width + 10 + cursor_size) &
                     (my >= mid_y - cursor_size) & (my <= mid_y + cursor_size))
                 {
                      cursor_x= java.lang.Math.min(image_width - 1, cursor_x + 1);
                      record_sw = 0;
                      repaint();
                      return true; 
                 }
                 if ((mx >= mid_x - cursor_size) & (mx <= mid_x + cursor_size) &
                     (my >= margin_y - 10 - cursor_size) & (my <= margin_y - 10))
                 {
                      cursor_y = java.lang.Math.max(0, cursor_y - 1);
                      record_sw = 0;
                      repaint();
                      return true;
                 }
                 if ((mx >= mid_x - cursor_size) & (mx <= mid_x + cursor_size) &
                     (my >= margin_y + image_height + 10) & (my <= margin_y + image_height + 10 + cursor_size))
                 {
                      cursor_y = java.lang.Math.min(image_height - 1, cursor_y + 1);
                      record_sw = 0;
                      repaint();
                      return true;
                 }
            }
            else
            {
                 if ((mx >= cursor_pad_x - 5 - 2 * cursor_size) & (mx <= cursor_pad_x - 5 - cursor_size) &
                     (my >= cursor_pad_y - cursor_size - 5) & (my <= cursor_pad_y + cursor_size + 5))
                 {
                      cursor_x = java.lang.Math.max(0, cursor_x - 1);
                      record_sw = 0;
                      repaint();
                      return true; 
                 }
                 if ((mx >= cursor_pad_x + 5 + cursor_size) & (mx <= cursor_pad_x + 5 + 2 * cursor_size) &
                     (my >= cursor_pad_y - cursor_size - 5) & (my <= cursor_pad_y + cursor_size + 5))
                 {
                      cursor_x= java.lang.Math.min(image_width - 1, cursor_x + 1);
                      record_sw = 0;
                      repaint();
                      return true; 
                 }
                 if ((mx >= cursor_pad_x - 5 - cursor_size) & (mx <= cursor_pad_x + 5 + cursor_size) &
                     (my >= cursor_pad_y - 5 - 2 * cursor_size) & (my <= cursor_pad_y - 5 - cursor_size))
                 {
                      cursor_y = java.lang.Math.max(0, cursor_y - 1);
                      record_sw = 0;
                      repaint();
                      return true;
                 }
                 if ((mx >= cursor_pad_x - 5 - cursor_size) & (mx <= cursor_pad_x + 5 + cursor_size) &
                     (my >= cursor_pad_y + 5 + cursor_size) & (my <= cursor_pad_y + 5 + 2 * cursor_size))
                 {
                      cursor_y = java.lang.Math.min(image_height - 1, cursor_y + 1);
                      record_sw = 0;
                      repaint();
                      return true;
                 }
            
            }
                 
            if (record_button.test(mx, my))
            {
                 if (record_sw == 0)
                 {
                     if (save_index == 1000)
                         save_index = 0;
                     real_y = image_height - cursor_y - 1;
                     save_x[save_index] = cursor_x;
                     save_y[save_index] = real_y;
                     distance = java.lang.Math.sqrt((cursor_x - polar_origin_x) * (cursor_x - polar_origin_x) +
                                                    (real_y - polar_origin_y) * (real_y - polar_origin_y));
                     save_distance[save_index] = formatdouble(distance, 10, 2);
                     if (cursor_x == polar_origin_x)
                     {
                         if (polar_sw == 1)
                         {
                             if (real_y >= polar_origin_y)
                                 save_angle[save_index] = "    1.5708";
                             else
                                 save_angle[save_index] = "    4.7124";
                             if (real_y == polar_origin_y)
                                 save_angle[save_index] = " undefined";
                         }
                         else
                         {
                             if (real_y >= polar_origin_y)
                                 save_angle[save_index] = "     90.00";
                             else
                                 save_angle[save_index] = "    270.00";
                             if (real_y == polar_origin_y)
                                 save_angle[save_index] = " undefined";
                         }
                     }
                     else
                     {
                        angle = java.lang.Math.atan(1.0 * (real_y - polar_origin_y)/(cursor_x - polar_origin_x));
                        if (cursor_x < polar_origin_x)
                            angle = Math.PI + angle;
                        if (angle < 0)
                            angle = angle + 2 * Math.PI;
                        if (polar_sw == 2)
                        {
                            angle = angle * 360 / (2 * Math.PI);
                            save_angle[save_index] = formatdouble(angle, 10, 2);
                        }
                        else
                            save_angle[save_index] = formatdouble(angle, 10, 4);
                     }
                     save_index = save_index + 1;
                     record_sw = 1;
                     repaint();
                     return true;                 
                 }
            }
            if (clear_button.test(mx, my))
            {
                save_index = 0;
                record_sw = 0;
                repaint();
                return true;  
            }
            if (list_button.test(mx, my) & (display_sw == 1))
            {
                list_window = new DataDisplayFrame("List of marked points");
                list_window.hide();
                list_window.clearText();
                list_window.addText("The way in which you copy information from this window into\n");
                list_window.addText("another window depends on the browser and operating system you are\n");
                list_window.addText("using.  One of the following methods should work.\n\n");
                list_window.addText("*  Highlight the information to be copied in this window.\n");
                list_window.addText("   Then copy it by pressing command-c.   Next click in the area\n");
                list_window.addText("   into which it is to be pasted and press command-v.\n\n");
                list_window.addText("*  Highlight the information to be copied in this window.\n");
                list_window.addText("   Then copy it by pressing control-c.   Next click in the area\n");
                list_window.addText("   into which it is to be pasted and press control-v.\n\n");
                list_window.addText("*  Highlight the information to be copied in this window.\n");
                list_window.addText("   then drag it into the window into which it is to be pasted.\n\n");

                if (cas_sw == 0)  // Format for Maple
                {
                    list_window.addText("n := ");
                    list_window.addText(String.valueOf(save_index));
                    list_window.addText(";\n\n");
                    list_window.addText("x := [");
                    for (int i = 0; i < save_index; i = i + 1)
                    {
                         list_window.addText(String.valueOf(save_x[i]));
                         if (i < save_index - 1)
                         {
                            list_window.addText(",  ");
                            if (i == 10 * (i/ 10) + 9)
                                list_window.addText("\n          ");
                         }
                    }
                    list_window.addText("];\n\n");
                    list_window.addText("y := [");
                    for (int i = 0; i < save_index; i = i + 1)
                    {
                         list_window.addText(String.valueOf(save_y[i]));
                         if (i < save_index - 1)
                         {
                            list_window.addText(",  ");
                            if (i == 10 * (i/ 10) + 9)
                                list_window.addText("\n          ");
                         }
                    }
                    list_window.addText("];\n\n");
                    if (polar_sw > 0)
                    {
                        list_window.addText("r := [");
                        for (int i = 0; i < save_index; i = i + 1)
                        {
                             list_window.addText(save_distance[i]);
                             if (i < save_index - 1)
                             {
                                 list_window.addText(", ");
                                 if (i == 10 * (i/10) + 9)
                                list_window.addText("\n          ");
                             }
                        }
                        list_window.addText("];\n\n");
                        list_window.addText("t := [");
                        for (int i = 0; i < save_index; i = i + 1)
                        {
                             list_window.addText(save_angle[i]);
                             if (i < save_index - 1)
                             {
                                 list_window.addText(", ");
                                 if (i == 10 * (i/10) + 9)
                                list_window.addText("\n          ");
                             }
                        }
                        list_window.addText("];\n\n");
                    }
                }
                else
                if (cas_sw == 1)   // Format for Mathematica
                {
                    list_window.addText("n := ");
                    list_window.addText(String.valueOf(save_index));
                    list_window.addText("\n\n");
                    list_window.addText("x := {");
                    for (int i = 0; i < save_index; i = i + 1)
                    {
                         list_window.addText(String.valueOf(save_x[i]));
                         if (i < save_index - 1)
                         {
                            list_window.addText(",  ");
                            if (i == 10 * (i/ 10) + 9)
                                list_window.addText("\n          ");
                         }
                    }
                    list_window.addText("}\n\n");
                    list_window.addText("y := {");
                    for (int i = 0; i < save_index; i = i + 1)
                    {
                         list_window.addText(String.valueOf(save_y[i]));
                         if (i < save_index - 1)
                         {
                            list_window.addText(",  ");
                            if (i == 10 * (i/ 10) + 9)
                                list_window.addText("\n          ");
                         }
                    }
                    list_window.addText("}\n\n");
                    if (polar_sw > 0)
                    {
                        list_window.addText("r := {");
                        for (int i = 0; i < save_index; i = i + 1)
                        {
                             list_window.addText(save_distance[i]);
                             if (i < save_index - 1)
                             {
                                 list_window.addText(", ");
                                 if (i == 10 * (i/10) + 9)
                                list_window.addText("\n          ");
                             }
                        }
                        list_window.addText("}\n\n");
                        list_window.addText("t := {");
                        for (int i = 0; i < save_index; i = i + 1)
                        {
                             list_window.addText(save_angle[i]);
                             if (i < save_index - 1)
                             {
                                 list_window.addText(", ");
                                 if (i == 10 * (i/10) + 9)
                                list_window.addText("\n          ");
                             }
                        }
                        list_window.addText("}\n\n");
                    }
                }
                if (cas_sw == 2)  // Format for Excel
                {
                    if (polar_sw == 0)
                        list_window.addText("x-coordinate \t y-coordinate\n\n");
                    if (polar_sw == 1)
                        list_window.addText("x-coordinate \t y-coordinate \t distance \t angle (radians)\n\n");
                    if (polar_sw == 2)
                        list_window.addText("x-coordinate \t y-coordinate \t distance \t angle (degrees)\n\n");
                    for (int i = 0; i < save_index; i = i + 1)
                    {
                         list_window.addText(leftfill(6, String.valueOf(save_x[i])));
                         list_window.addText("\t ");
                         list_window.addText(leftfill(6, String.valueOf(save_y[i])));
                         if (polar_sw > 0)
                             list_window.addText("\t" + save_distance[i] + "\t" + save_angle[i]);
                         list_window.addText("\n");                
                    }
                }
                list_window.pack();
                list_window.show();
            }
            return true;
       }
       
       public void tell_error(String message)
       {
              message_window = new DataDisplayFrame("Expression Error");
              message_window.hide();
              message_window.clearText();
              message_window.addText("An error has been detected in an algebraic expression.\n\n");
              message_window.addText(message);
              message_window.addText("\n\n");
              message_window.addText(recovery_message_line_1);
              message_window.addText("\n");
              message_window.addText(recovery_message_line_2);
              message_window.addText("\n");
              message_window.pack();
              message_window.show();
              return;
       }
       
       //
       //   Used to right justify output
       //
       
       public String leftfill(int n, String str)
       {
           int      k;
           String   body;
           body = str;
           k = body.length();
           body = "                    ";
           body = body.substring(0, n - k) + str;
           return body;
       }
}

//
//    The following is used to display information in a form that
//    can be imported into another program by cut-and-paste
//

class DataDisplayFrame extends Frame
{
      final    static    Font   textfont = new Font("Courier", Font.PLAIN, 12);

      TextArea                  txt      = new TextArea();

      public DataDisplayFrame (String title)
      {
             super(title);
             txt.setEditable(true);
             txt.setFont(textfont);
             add(txt);
      }

      public void addText(String text)
      {
             txt.setText(txt.getText() + text);
      }

      public void clearText()
      {
             txt.setText("");
      }

      public boolean handleEvent(Event evt)
      {
             if (evt.id == Event.WINDOW_DESTROY)
                 dispose();
             return super.handleEvent(evt);
      }
}

//
//    The following were written by Frank Wattenberg
//

class VCRButton
{
      //
      //    On-off button
      //    Click to turn on
      //

      public      int     left;
      public      int     top;
      public      int     width;
      public      int     height;
      public      String  label;
      public      Color   button_color, back_color, shadow_color;
      
      public VCRButton(int left, int top, int width, int height, 
                       Color button_color, Color back_color, Color shadow_color, String label)
      {
             this.left          = left;
             this.top           = top;
             this.width         = width;
             this.height        = height;
             this.button_color  = button_color;
             this.back_color    = back_color;
             this.shadow_color  = shadow_color;
             this.label         = label;
      }

      public void draw_on(Graphics g)
      {
             g.setColor(back_color);
             g.fillRect(left, top, width, height);
             g.setColor(button_color);
             g.fillRect(left + 3, top + 3, width - 3, height - 3);
             g.setColor(shadow_color);
             g.drawString(label, left + width/2 - g.getFontMetrics().stringWidth(label)/2, top + height + height/2);
      }

      public void draw_off(Graphics g)
      {
             g.setColor(back_color);
             g.fillRect(left, top, width, height);
             g.setColor(shadow_color);
             g.fillRect(left + 3, top + 3, width - 3, height - 3);
             g.setColor(button_color);
             g.fillRect(left, top, width - 3, height - 3);
             g.setColor(shadow_color);
             g.drawString(label, left + width/2 - g.getFontMetrics().stringWidth(label)/2, top + height + height/2);
      }

      public boolean test(int mx, int my)
      {
             if ((mx >= left) & (mx <= left + width) &
                 (my >= top) & (my <= top + height))
                return true;
             else
                return false; 
      }
}

//
// The following was written by Darius Bacon
//

abstract class Expr {

    /** @return the value given the current variable values */
    public abstract double value();

    /** Binary operator: addition        */  public static final int ADD =  0;  
    /** Binary operator: subtraction     */  public static final int SUB =  1;
    /** Binary operator: multiplication  */  public static final int MUL =  2;
    /** Binary operator: division        */  public static final int DIV =  3;
    /** Binary operator: exponentiation  */  public static final int POW =  4;
    /** Binary operator: arctangent      */  public static final int ATAN2 = 5;
    /** Binary operator: maximum         */  public static final int MAX =  6;
    /** Binary operator: minimum         */  public static final int MIN =  7;
    /** Binary operator: less than       */  public static final int LT  =  8;
    /** Binary operator: less or equal   */  public static final int LE  =  9;
    /** Binary operator: equality        */  public static final int EQ  = 10;
    /** Binary operator: inequality      */  public static final int NE  = 11;
    /** Binary operator: greater or equal*/  public static final int GE  = 12;
    /** Binary operator: greater than    */  public static final int GT  = 13;
    /** Binary operator: logical and     */  public static final int AND = 14;
    /** Binary operator: logical or      */  public static final int OR  = 15;
  
    /** Unary operator: absolute value*/   public static final int ABS   = 100;
    /** Unary operator: arccosine */       public static final int ACOS  = 101;
    /** Unary operator: arcsine   */       public static final int ASIN  = 102;
    /** Unary operator: arctangent*/       public static final int ATAN  = 103;
    /** Unary operator: ceiling   */       public static final int CEIL  = 104;
    /** Unary operator: cosine    */       public static final int COS   = 105;
    /** Unary operator: e to the x*/       public static final int EXP   = 106;
    /** Unary operator: floor     */       public static final int FLOOR = 107;
    /** Unary operator: natural log*/      public static final int LOG   = 108;
    /** Unary operator: negation        */ public static final int NEG   = 109;
    /** Unary operator: rounding  */       public static final int ROUND = 110;
    /** Unary operator: sine      */       public static final int SIN   = 111;
    /** Unary operator: square root */     public static final int SQRT  = 112;
    /** Unary operator: tangent */         public static final int TAN   = 113;

    /** Make a literal expression.
     * @param v the constant value of the expression
     * @return an expression whose value is always v */
    public static Expr makeLiteral(double v) { 
	return new LiteralExpr(v); 
    }
    /** Make an expression that applies a unary operator to an operand.
     * @param rator a code for a unary operator
     * @param rand operand
     * @return an expression meaning rator(rand)
     */
    public static Expr makeApp1(int rator, Expr rand) {
	Expr app = new UnaryExpr(rator, rand);
	return rand instanceof LiteralExpr
	    ? new LiteralExpr(app.value()) 
	    : app;
    }
    /** Make an expression that applies a binary operator to two operands.
     * @param rator a code for a binary operator
     * @param rand0 left operand
     * @param rand1 right operand
     * @return an expression meaning rator(rand0, rand1)
     */
    public static Expr makeApp2(int rator, Expr rand0, Expr rand1) {
	Expr app = new BinaryExpr(rator, rand0, rand1);
	return rand0 instanceof LiteralExpr && rand1 instanceof LiteralExpr
	    ? new LiteralExpr(app.value()) 
	    : app;
    }
    /** Make a conditional expression.
     * @param test `if' part
     * @param consequent `then' part
     * @param alternative `else' part
     * @return an expression meaning `if test, then consequent, else
     *         alternative' 
     */
    public static Expr makeIfThenElse(Expr test,
				      Expr consequent,
				      Expr alternative) {
	Expr cond = new ConditionalExpr(test, consequent, alternative);
	if (test instanceof LiteralExpr &&
	    consequent instanceof LiteralExpr &&
	    alternative instanceof LiteralExpr)
	    return new LiteralExpr(cond.value());
	else
	    return cond;
    }
}

// These classes are all private to this module so that I can get rid
// of them later.  For applets you want to use as few classes as
// possible to avoid http connections at load time; it'd be profitable
// to replace all these subtypes with bytecodes for a stack machine,
// or perhaps a type that's the union of all of them (see class Node
// in java/demo/SpreadSheet/SpreadSheet.java).

class LiteralExpr extends Expr {
    double v;
    LiteralExpr(double v) { this.v = v; }
    public double value() { return v; }
}

class UnaryExpr extends Expr {
    int rator;
    Expr rand;

    UnaryExpr(int rator, Expr rand) { 
	this.rator = rator;
	this.rand = rand;
    }

    public double value() {
	double arg = rand.value();
	switch (rator) {
	case ABS:   return Math.abs(arg);
	case ACOS:  return Math.acos(arg);
	case ASIN:  return Math.asin(arg);
	case ATAN:  return Math.atan(arg);
	case CEIL:  return Math.ceil(arg);
	case COS:   return Math.cos(arg);
	case EXP:   return Math.exp(arg);
	case FLOOR: return Math.floor(arg);
	case LOG:   return Math.log(arg);
	case NEG:   return -arg;
	case ROUND: return Math.round(arg);
	case SIN:   return Math.sin(arg);
	case SQRT:  return Math.sqrt(arg);
	case TAN:   return Math.tan(arg);
	default: throw new RuntimeException("BUG: bad rator");
	}
    }
}

class BinaryExpr extends Expr {
    int rator;
    Expr rand0, rand1;

    BinaryExpr(int rator, Expr rand0, Expr rand1) {
	this.rator = rator;
	this.rand0 = rand0;
	this.rand1 = rand1;
    }
    public double value() {
	double arg0 = rand0.value();
	double arg1 = rand1.value();
	switch (rator) {
	case ADD:   return arg0 + arg1;
	case SUB:   return arg0 - arg1;
	case MUL:   return arg0 * arg1;
	case DIV:   return arg0 / arg1; // division by 0 has IEEE 754 behavior
	case POW:   return Math.pow(arg0, arg1);
	case ATAN2: return Math.atan2(arg0, arg1);
	case MAX:   return arg0 < arg1 ? arg1 : arg0;
	case MIN:   return arg0 < arg1 ? arg0 : arg1;
        case LT:    return arg0 <  arg1 ? 1.0 : 0.0;
        case LE:    return arg0 <= arg1 ? 1.0 : 0.0;
        case EQ:    return arg0 == arg1 ? 1.0 : 0.0;
        case NE:    return arg0 != arg1 ? 1.0 : 0.0;
        case GE:    return arg0 >= arg1 ? 1.0 : 0.0;
        case GT:    return arg0  > arg1 ? 1.0 : 0.0;
        case AND:   return arg0 != 0 && arg1 != 0 ? 1.0 : 0.0;
        case OR:    return arg0 != 0 || arg1 != 0 ? 1.0 : 0.0; 
	default: throw new RuntimeException("BUG: bad rator");
	}
    }
}

class ConditionalExpr extends Expr {
    Expr test, consequent, alternative;

    ConditionalExpr(Expr test, Expr consequent, Expr alternative) {
	this.test = test;
	this.consequent = consequent;
	this.alternative = alternative;
    }

    public double value() {
	return test.value() != 0 ? consequent.value() : alternative.value();
    }
}

// Operator-precedence parser.
// Copyright 1996 by Darius Bacon; see the file COPYING.

/** 
  Parses strings representing mathematical formulas with variables.
  The following operators, in descending order of precedence, are
  defined:

  <UL>
  <LI>^ (raise to a power)
  <LI>* /
  <LI>Unary minus (-x)
  <LI>+ -
  <LI>&lt; &lt;= = &lt;&gt; &gt;= &gt;
  <LI>and
  <LI>or
  </UL>

  ^ associates right-to-left; other operators associate left-to-right.

  <P>These functions are defined: 
    abs, acos, asin, atan, 
    ceil, cos, exp, floor, 
    log, round, sin, sqrt, 
    tan.  Each requires one argument enclosed in parentheses.

  <P>There are also binary functions: atan2, min, max; and a ternary
  conditional function: if(test, then, else).

  <P>Whitespace outside identifiers is ignored.

  <P>Examples:
  <UL>
  <LI>42
  <LI>2-3
  <LI>cos(x^2) + sin(x^2)
  <UL> */

class Parser {

    // Built-in constants
    static private Variable pi = Variable.make("pi");
    static {
	pi.setValue(Math.PI);
    }

    /** Return the expression denoted by the input string.
     *
     *       @param input the unparsed expression
     *      @exception SyntaxException if the input is unparsable */
    static public Expr parse(String input) throws SyntaxException {
	return new Parser().parseString(input);
    }

    /** Set of Variable's that are allowed to appear in input expressions. 
     * If null, any Variable is allowed. */
    private Hashtable allowedVariables = null;

    public void allow(Variable variable) {
	if (null == allowedVariables) {
	    allowedVariables = new Hashtable();
	    allowedVariables.put(pi, pi);
	}
	allowedVariables.put(variable, variable);
    }

    Scanner tokens = null;
    private Token token = null;

    /** Return the expression denoted by the input string.
     *
     *       @param input the unparsed expression
     *      @exception SyntaxException if the input is unparsable */
    public Expr parseString(String input) throws SyntaxException {
	String operatorChars = "+-*/^<>=,";
	tokens = new Scanner(input, operatorChars);
	return reparse();
    }

    private Expr reparse() throws SyntaxException {
	tokens.index = -1;
	nextToken();
	Expr expr = parseExpr(0);
	if (token.ttype != Token.TT_EOF)
	    throw error("Incomplete expression",
			SyntaxException.INCOMPLETE, null);
	return expr;
    }

    private void nextToken() {
	token = tokens.nextToken();
    }

    private Expr parseExpr(int precedence) throws SyntaxException {
	Expr expr = parseFactor();
    loop:
	for (;;) {
	    int l, r, rator;   

	    // The operator precedence table.
	    // l = left precedence, r = right precedence, rator = operator.
	    // Higher precedence values mean tighter binding of arguments.
	    // To associate left-to-right, let r = l+1;
	    // to associate right-to-left, let r = l.

	    switch (token.ttype) {

	    case '<':         l = 20; r = 21; rator = Expr.LT; break;
	    case Token.TT_LE: l = 20; r = 21; rator = Expr.LE; break;
	    case '=':         l = 20; r = 21; rator = Expr.EQ; break;
	    case Token.TT_NE: l = 20; r = 21; rator = Expr.NE; break;
	    case Token.TT_GE: l = 20; r = 21; rator = Expr.GE; break;
	    case '>':         l = 20; r = 21; rator = Expr.GT; break;

	    case '+': l = 30; r = 31; rator = Expr.ADD; break;
	    case '-': l = 30; r = 31; rator = Expr.SUB; break;
	
	    case '/': l = 40; r = 41; rator = Expr.DIV; break;
	    case '*': l = 40; r = 41; rator = Expr.MUL; break;
	
	    case '^': l = 50; r = 50; rator = Expr.POW; break;
	
	    default:
		if (token.ttype == Token.TT_WORD && token.sval.equals("and")) {
		    l = 5; r = 6; rator = Expr.AND; break;
		} 
		if (token.ttype == Token.TT_WORD && token.sval.equals("or")) {
		    l = 10; r = 11; rator = Expr.OR; break;
		} 
		break loop;
	    }

	    if (l < precedence)
		break loop;

	    nextToken();
	    expr = Expr.makeApp2(rator, expr, parseExpr(r));
	}
	return expr;
    }

    static private final String[] procs1 = {
	"abs", "acos", "asin", "atan", 
	"ceil", "cos", "exp", "floor", 
	"log", "round", "sin", "sqrt", 
	"tan"
    };
    static private final int[] rators1 = {
	Expr.ABS, Expr.ACOS, Expr.ASIN, Expr.ATAN, 
	Expr.CEIL, Expr.COS, Expr.EXP, Expr.FLOOR,
	Expr.LOG, Expr.ROUND, Expr.SIN, Expr.SQRT, 
	Expr.TAN
    };
	
    static private final String[] procs2 = {
	"atan2", "max", "min"
    };
    static private final int[] rators2 = {
	Expr.ATAN2, Expr.MAX, Expr.MIN
    };
	
    private boolean atStartOfFactor() {
	return token.ttype == Token.TT_NUMBER
	    || token.ttype == Token.TT_WORD
	    || token.ttype == '('
	    || token.ttype == '-';
    }

    private Expr parseFactor() throws SyntaxException {
	switch (token.ttype) {
	case Token.TT_NUMBER: {
	    Expr lit = Expr.makeLiteral(token.nval);
	    nextToken();
	    return lit;
	}
	case Token.TT_WORD: {
	    for (int i = 0; i < procs1.length; ++i)
		if (procs1[i].equals(token.sval)) {
		    nextToken();
		    expect('(');
		    Expr rand = parseExpr(0);
		    expect(')');
		    return Expr.makeApp1(rators1[i], rand);
		}

	    for (int i = 0; i < procs2.length; ++i)
		if (procs2[i].equals(token.sval)) {
		    nextToken();
		    expect('(');
		    Expr rand1 = parseExpr(0);
		    expect(',');
		    Expr rand2 = parseExpr(0);
		    expect(')');
		    return Expr.makeApp2(rators2[i], rand1, rand2);
		}

	    if (token.sval.equals("if")) {
		nextToken();
		expect('(');
		Expr test = parseExpr(0);
		expect(',');
		Expr consequent = parseExpr(0);
		expect(',');
		Expr alternative = parseExpr(0);
		expect(')');
		return Expr.makeIfThenElse(test, consequent, alternative);
	    }

	    Expr var = Variable.make(token.sval);
	    if (null != allowedVariables && null == allowedVariables.get(var))
		throw error("Unknown variable",
			    SyntaxException.UNKNOWN_VARIABLE, null);
	    nextToken();
	    return var;
	}
	case '(': {
	    nextToken();
	    Expr enclosed = parseExpr(0);
	    expect(')');
	    return enclosed;
	}
	case '-': 
	    nextToken();
	    return Expr.makeApp1(Expr.NEG, parseExpr(35));
	case Token.TT_EOF:
	    throw error("Expected a factor",
			SyntaxException.PREMATURE_EOF, null);
	default:
	    throw error("Expected a factor",
			SyntaxException.BAD_FACTOR, null);
	}
    }

    private SyntaxException error(String complaint, 
				  int reason, 
				  String expected) {
	return new SyntaxException(complaint, this, reason, expected);
    }

    private void expect(int ttype) throws SyntaxException {
	if (token.ttype != ttype)
	    throw error("'" + (char)ttype + "' expected",
			SyntaxException.EXPECTED, "" + (char)ttype);
	nextToken();
    }


    // Error correction

    boolean tryCorrections() {
	return tryInsertions() || tryDeletions() || trySubstitutions();
    }

    private boolean tryInsertions() {
	Vector v = tokens.tokens;
	for (int i = tokens.index; 0 <= i; --i) {
	    Token t;
	    if (i < v.size()) {
		t = (Token) v.elementAt(i);
	    } else {
		String s = tokens.getInput();
		t = new Token(Token.TT_EOF, 0, s, s.length(), s.length());
	    }
	    Token[] candidates = possibleInsertions(t);
	    for (int j = 0; j < candidates.length; ++j) {
		v.insertElementAt(candidates[j], i);
		try {
		    reparse();
		    return true;
		} catch (SyntaxException se) { 
		    v.removeElementAt(i);
		}
	    }
	}
	return false;
    }

    private boolean tryDeletions() {
	Vector v = tokens.tokens;
	for (int i = tokens.index; 0 <= i; --i) {
	    if (v.size() <= i)
		continue;
	    Object t = v.elementAt(i);
	    v.remove(i);
	    try {
		reparse();
		return true;
	    } catch (SyntaxException se) {
		v.insertElementAt(t, i);
	    }
	}
	return false;
    }

    private boolean trySubstitutions() {
	Vector v = tokens.tokens;
	for (int i = tokens.index; 0 <= i; --i) {
	    if (v.size() <= i)
		continue;
	    Token t = (Token) v.elementAt(i);
	    Token[] candidates = possibleSubstitutions(t);
	    for (int j = 0; j < candidates.length; ++j) {
		v.setElementAt(candidates[j], i);
		try {
		    reparse();
		    return true;
		} catch (SyntaxException se) { }
	    }
	    v.setElementAt(t, i);
	}
	return false;
    }

    private Token[] possibleInsertions(Token t) {
	String ops = tokens.getOperatorChars();
	Token[] ts = 
	    new Token[ops.length() + 6 + procs1.length + procs2.length];
	int i = 0;

	Token one = new Token(Token.TT_NUMBER, 1, "1", t);
	ts[i++] = one;

	for (int j = 0; j < ops.length(); ++j)
	    ts[i++] = new Token(ops.charAt(j), 0, "" + ops.charAt(j), t);

	ts[i++] = new Token(Token.TT_WORD, 0, "x", t);

	for (int k = 0; k < procs1.length; ++k)
	    ts[i++] = new Token(Token.TT_WORD, 0, procs1[k], t);

	for (int m = 0; m < procs2.length; ++m)
	    ts[i++] = new Token(Token.TT_WORD, 0, procs2[m], t);

	ts[i++] = new Token(Token.TT_LE, 0, "<=", t);
	ts[i++] = new Token(Token.TT_NE, 0, "<>", t);
	ts[i++] = new Token(Token.TT_GE, 0, ">=", t);
	ts[i++] = new Token(Token.TT_WORD, 0, "if", t);
	
	return ts;
    }

    private Token[] possibleSubstitutions(Token t) {
	return possibleInsertions(t);
    }
}

class Scanner {

    private String s;
    private String operatorChars;

    Vector tokens = new Vector();
    int index = -1;

    public Scanner(String string, String operatorChars) {
        this.s = string;
	this.operatorChars = operatorChars + "()";

        int i = 0;
	do {
	    i = scanToken(i);
	} while (i < s.length());
    }

    public String getInput() {
	return s;
    }

    public String getOperatorChars() {
	return operatorChars;
    }

    // The tokens may have been diddled, so this can be different from 
    // getInput().
    public String toString() {
	StringBuffer sb = new StringBuffer();
	int whitespace = 0;
	for (int i = 0; i < tokens.size(); ++i) {
	    Token t = (Token) tokens.elementAt(i);

	    int spaces = (whitespace != 0 ? whitespace : t.leadingWhitespace);
	    if (i == 0) 
		spaces = 0;
	    else if (spaces == 0 && !joinable((Token) tokens.elementAt(i-1), t))
		spaces = 1;
	    for (int j = spaces; 0 < j; --j)
		sb.append(" ");

	    sb.append(t.sval);
	    whitespace = t.trailingWhitespace;
	}
	return sb.toString();
    }

    private boolean joinable(Token s, Token t) {
	return !(isAlphanumeric(s) && isAlphanumeric(t));
    }

    private boolean isAlphanumeric(Token t) {
	return t.ttype == Token.TT_WORD || t.ttype == Token.TT_NUMBER;
    }

    public boolean isEmpty() {
	return tokens.size() == 0;
    }

    public boolean atStart() {
	return index <= 0;
    }

    public boolean atEnd() {
	return tokens.size() <= index;
    }

    public Token nextToken() {
	++index;
	return getCurrentToken();
    }

    public Token getCurrentToken() {
	if (atEnd())
	    return new Token(Token.TT_EOF, 0, s, s.length(), s.length());
	return (Token) tokens.elementAt(index);
    }

    private int scanToken(int i) {
        while (i < s.length() && Character.isWhitespace(s.charAt(i)))
            ++i;

        if (i == s.length()) {
	    return i;
        } else if (0 <= operatorChars.indexOf(s.charAt(i))) {
	    if (i+1 < s.length()) {
		String pair = s.substring(i, i+2);
		int ttype = 0;
		if (pair.equals("<="))
		    ttype = Token.TT_LE;
		else if (pair.equals(">="))
		    ttype = Token.TT_GE;
		else if (pair.equals("<>"))
		    ttype = Token.TT_NE;
		if (0 != ttype) {
		    tokens.addElement(new Token(ttype, 0, s, i, i+2));
		    return i+2;
		}
	    }
	    tokens.addElement(new Token(s.charAt(i), 0, s, i, i+1));
            return i+1;
        } else if (Character.isLetter(s.charAt(i))) {
            return scanSymbol(i);
        } else if (Character.isDigit(s.charAt(i)) || '.' == s.charAt(i)) {
            return scanNumber(i);
        } else {
            tokens.addElement(makeErrorToken("Unknown lexeme", i, i+1));
            return i+1;
        }
    }

    private int scanSymbol(int i) {
	int from = i;
        while (i < s.length() 
	       && (Character.isLetter(s.charAt(i))
		   || Character.isDigit(s.charAt(i))))
            ++i;
	tokens.addElement(new Token(Token.TT_WORD, 0, s, from, i));
	return i;
    }

    private int scanNumber(int i) {
	int from = i;

        // We include letters in our purview because otherwise we'd
        // accept a word following with no intervening space.
        for (; i < s.length(); ++i)
	    if ('.' != s.charAt(i)
		&& !Character.isDigit(s.charAt(i))
		&& !Character.isLetter(s.charAt(i)))
                break;

        String text = s.substring(from, i);
	double nval;
        try {
            nval = Double.valueOf(text).doubleValue();
        } catch (NumberFormatException nfe) {
            tokens.addElement(makeErrorToken("Not a number", from, i));
	    return i;
        }

	tokens.addElement(new Token(Token.TT_NUMBER, nval, s, from, i));
	return i;
    }

    private Token makeErrorToken(String complaint, int from, int i) {
	// TODO: incorporate the complaint somehow
	return new Token(Token.TT_ERROR, 0, s, from, i);
    }
}

/**
 * An exception indicating a problem in parsing an expression.  It can
 * produce a short, cryptic error message (with getMessage()) or a
 * long, hopefully helpful one (with explain()).
 */

class SyntaxException extends Exception {

    /** An error code meaning the input string had stuff left over. */
    public static final int INCOMPLETE = 0;

    /** An error code meaning the parser ran into a non-value token
      (like "/") at a point it was expecting a value (like "42" or
      "x^2"). */
    public static final int BAD_FACTOR = 1;

    /** An error code meaning the parser hit the end of its input
        before it had parsed a full expression. */
    public static final int PREMATURE_EOF = 2;

    /** An error code meaning the parser hit an unexpected token at a
        point it expected to see some particular other token. */
    public static final int EXPECTED = 3;

    /** An error code meaning the expression includes a variable not
        on the `approved' list. */
    public static final int UNKNOWN_VARIABLE = 4;

    /** Make a new instance.
     * @param complaint short error message
     * @param parser the parser that hit this snag
     * @param reason one of the error codes defined in this class
     * @param expected if nonnull, the token the parser expected to
     *        see (in place of the erroneous token it did see)
     */
    public SyntaxException(String complaint, 
			   Parser parser,
			   int reason, 
			   String expected) {
	super(complaint); 
	this.reason = reason;
	this.parser = parser;
	this.scanner = parser.tokens;
	this.expected = expected;
    }

    /** Give a long, hopefully helpful error message.
     * @returns the message */
    public String explain() {
	StringBuffer sb = new StringBuffer();

	sb.append("I don't understand your formula ");
	quotify(sb, scanner.getInput());
	sb.append(".\n\n");

	explainWhere(sb);
	explainWhy(sb);
	explainWhat(sb);

	return sb.toString();
    }

    private Parser parser;
    private Scanner scanner;

    private int reason;
    private String expected;

    private String fixedInput = "";

    private void explainWhere(StringBuffer sb) {
	if (scanner.isEmpty()) {
	    sb.append("It's empty!\n");
	} else if (scanner.atStart()) {
	    sb.append("It starts with ");
	    quotify(sb, theToken());
	    if (isLegalToken()) 
		sb.append(", which can never be the start of a formula.\n");
	    else
		sb.append(", which is a meaningless symbol to me.\n");
	} else {
	    sb.append("I got as far as ");
	    quotify(sb, asFarAs());
	    sb.append(" and then ");
	    if (scanner.atEnd()) {
		sb.append("reached the end unexpectedly.\n");
	    } else {
		sb.append("saw ");
		quotify(sb, theToken());
		if (isLegalToken()) 
		    sb.append(".\n");
		else
		    sb.append(", which is a meaningless symbol to me.\n");
	    }
	}
    }

    private void explainWhy(StringBuffer sb) {
	switch (reason) {
	case INCOMPLETE: 
	    if (isLegalToken())
		sb.append("The first part makes sense, but I don't see " +
			  "how the rest connects to it.\n");
	    break;
	case BAD_FACTOR:
	case PREMATURE_EOF:
	    sb.append("I expected a value");
	    if (!scanner.atStart()) sb.append(" to follow");
	    sb.append(", instead.\n");
	    break;
	case EXPECTED:
	    sb.append("I expected ");
	    quotify(sb, expected);
	    sb.append(" at that point, instead.\n");
	    break;
	case UNKNOWN_VARIABLE:
	    sb.append("That variable has no value.\n");
	    break;
	default:
	    throw new Error("Can't happen");
	}
    }

    private void explainWhat(StringBuffer sb) {
	fixedInput = tryToFix();
	if (null != fixedInput) {
	    sb.append("An example of a formula I can parse is ");
	    quotify(sb, fixedInput);
	    sb.append(".\n");
	}
    }

    private String tryToFix() {
	return (parser.tryCorrections() ? scanner.toString() : null);
    }

    private void quotify(StringBuffer sb, String s) {
	sb.append('"');
	sb.append(s);
	sb.append('"');
    }

    private String asFarAs() {
	Token t = scanner.getCurrentToken();
	int point = t.location - t.leadingWhitespace;
	return scanner.getInput().substring(0, point);
    }

    private String theToken() {
	return scanner.getCurrentToken().sval;
    }

    private boolean isLegalToken() {
	Token t = scanner.getCurrentToken();
	return t.ttype != Token.TT_EOF
	    && t.ttype != Token.TT_ERROR;
    }
}

class Token {
    public static final int TT_ERROR  = -1;
    public static final int TT_EOF    = -2;
    public static final int TT_NUMBER = -3;
    public static final int TT_WORD   = -4;
    public static final int TT_LE     = -5;
    public static final int TT_NE     = -6;
    public static final int TT_GE     = -7;

    public Token(int ttype, double nval, String input, int start, int end) {
        this.ttype = ttype;
        this.sval = input.substring(start, end);
	this.nval = nval;
	this.location = start;
	
	int count = 0;
	for (int i = start-1; 0 <= i; --i) {
	    if (!Character.isWhitespace(input.charAt(i)))
		break;
	    ++count;
	}
	this.leadingWhitespace = count;

	count = 0;
	for (int i = end; i < input.length(); ++i) {
	    if (!Character.isWhitespace(input.charAt(i)))
		break;
	    ++count;
	}
	this.trailingWhitespace = count;
    }

    Token(int ttype, double nval, String sval, Token token) {
	this.ttype = ttype;
	this.sval = sval;
	this.nval = nval;
	this.location = token.location;
	this.leadingWhitespace = token.leadingWhitespace;
	this.trailingWhitespace = token.trailingWhitespace;
    }

    public final int ttype;
    public final String sval;
    public final double nval;

    public final int location;

    public final int leadingWhitespace, trailingWhitespace;
}

/**
 * A variable is a simple expression with a name (like "x") and a
 * changeable value.
 */
class Variable extends Expr {
    private static Hashtable variables = new Hashtable();
    
    /**
     * Return the variable named `name'.  There can be only one
     * variable with the same name returned by this method; that is,
     * make(s1) == make(s2) if and only if s1.equals(s2).
     * @param name the variable's name
     * @return the variable; create it initialized to 0 if it doesn't
     *         yet exist */
    static public synchronized Variable make(String name) {
	Variable result = (Variable) variables.get(name);
	if (result == null)
	    variables.put(name, result = new Variable(name));
	return result;
    }

    private String name;
    private double val;

    /**
     * Create a new variable.
     * @param name the variable's name
     */
    public Variable(String name) { 
	this.name = name; val = 0; 
    }

    public String toString() { return name; }

    /** Get the value.
     * @return the current value */
    public double value() { 
	return val; 
    }
    /** Set the value.
     * @param value the new value */
    public void setValue(double value) { 
	val = value; 
    }

    public void set_value(double value) { 
	val = value; 
    }
}



