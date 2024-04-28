import ballerina/http;
import ballerina/sql;
import ballerinax/mysql;
import ballerinax/mysql.driver as _;

configurable string USER = ?;
configurable string PASSWORD = ?;
configurable string HOST = ?;
configurable int PORT = ?;
configurable string DATABASE = ?;

// The `Room` record to load records from `Rooms` table.
type Room record {|
    string id;
    string room_name;
    int capacity;
    string location;
    string features;
    string status;
    string available;
    int created_by;
    string created_date;
    int modified_by;
    string modified_date;
|};

type CreateRoom record {|
    string room_name;
    int capacity;
    string location;
    string features;
    string status;
    string available;
|};

type Response record {|
    int code;
    string message;
|};

//Room Booking Schema
type Bookings record {|
    int id;
    int room_id;
    int attendees;
    string reason;
    string booked_by;
    string start_time;
    string end_time;
    string resources;
    string booking_status;
    int created_by;
    string created_date;
    int modified_by;
    string modified_date;
|};
type CreateBooking record {|
    int room_id;
    int attendees;
    string reason;
    int booked_by;
    string start_time;
    string end_time;
    string resources;
|};
type CreateBookingResponse record {|
     int code;
     string message;
     int booking_id;
|};

service / on new http:Listener(8080) {

    private final mysql:Client db;

    function init() returns error? {

        // Initiate the mysql client at the start of the service. This will be used
        // throughout the lifetime of the service.
        //self.db = check new ("sql6.freesqldatabase.com", "sql6693962", "VEhKY47ZDU", "sql6693962", 3306);
        self.db = check new (host=HOST, user=USER, password=PASSWORD, port=PORT, database=DATABASE);
    }

    resource function get get_rooms() returns Room[]|error {
        // Execute simple query to retrieve all records from the `rooms` table.
        stream<Room, sql:Error?> RoomStream = self.db->query(`SELECT * FROM rooms`);

        // Process the stream and convert results to Room[] or return error.
        return from Room Room in RoomStream
            select Room;
    }

    resource function get get_rooms_available() returns Room[]|error {
        // Execute simple query to retrieve all records from the `rooms` table.
        stream<Room, sql:Error?> RoomStream = self.db->query(`SELECT * FROM rooms where status='active' and available='yes'`);

        // Process the stream and convert results to Room[] or return error.
        return from Room Room in RoomStream
            select Room;
    }

  resource function get get_room_details/[string id]() returns Room|Response|http:NotFound|error {
        // Execute simple query to fetch record with requested id.
        Room|sql:Error result = self.db->queryRow(`SELECT * FROM rooms WHERE id = ${id}`);

        // Check if record is available or not
        if result is sql:NoRowsError {
            //return http:NOT_FOUND;
            Response response={"code":400,"message":"No room found with id "+id};
            return response;
        } else {
            return result;
        }
    }
    
    resource function post create_room(CreateRoom room) returns Response|CreateRoom|error {
       _ = check self.db->execute(`
            INSERT INTO rooms (room_name, capacity, location, features, status, available,created_by,modified_by)
            VALUES (${room.room_name},${room.capacity}, ${room.location}, ${room.features}, ${room.status}, ${room.available},0,0);`);
        
        Response response={"code":201,"message":"Room created successfully"};
        return response;
    }

    resource function delete delete_room/[string id]() returns json|http:NotFound|error {
        //io:println(id);
        _ = check self.db->execute(`update rooms set status='inactive', available='no' WHERE id = ${id}`);
        Response response={"code":204,"message":"Room deleted successfully"};
        return response;
    }

    resource function post book_room(CreateBooking booking) returns CreateBookingResponse|error|int {
       sql:ExecutionResult result = check self.db->execute(`
            INSERT INTO bookings (room_id, attendees, reason, booked_by, start_time, end_time,resources)
            VALUES (${booking.room_id},${booking.attendees}, ${booking.reason}, ${booking.booked_by}, ${booking.start_time}, ${booking.end_time},${booking.resources});`);
        
          int|string? lastInsertId = result.lastInsertId;
            if lastInsertId is int {
                lastInsertId=lastInsertId;
            } else {
                return error("Unable to obtain last insert ID");
            }
            CreateBookingResponse response={"code":201,"message":"Booking created successfully","booking_id":<int>lastInsertId};
            return response;
    }

     resource function put booking_confirm/[string id]() returns json|http:NotFound|error {
        //io:println(id);
        _ = check self.db->execute(`update bookings set booking_status='booked', modified_date=CURRENT_TIMESTAMP WHERE id = ${id}`);
        Response response={"code":200,"message":"Booking confirmed successfully"};
        return response;
    }
    
     resource function delete booking_cancel/[string id]() returns json|http:NotFound|error {
        //io:println(id);
        _ = check self.db->execute(`update bookings set booking_status='canceled', modified_date=CURRENT_TIMESTAMP WHERE id = ${id}`);
        Response response={"code":204,"message":"Booking canceled successfully"};
        return response;
    }
    

    resource function get booking_status/[string id]() returns Bookings|Response|http:NotFound|error {
        // Execute simple query to fetch record with requested id.
        Bookings|sql:Error result = self.db->queryRow(`SELECT * FROM bookings WHERE id = ${id}`);

        // Check if record is available or not
        if result is sql:NoRowsError {
            //return http:NOT_FOUND;
            Response response={"code":400,"message":"No booking found with id "+id};
            return response;
        } else {
            return result;
        }
    }
    resource function get bookings/[string id]() returns Bookings|Response|http:NotFound|error {
        // Execute simple query to fetch record with requested id.
        Room|sql:Error result = self.db->queryRow(`SELECT * FROM bookings WHERE created_by = ${id}`);

        // Check if record is available or not
        if result is sql:NoRowsError {
            //return http:NOT_FOUND;
            Response response={"code":400,"message":"No bookings found for id "+id};
            return response;
        } else {
            return result;
        }
    }
}
