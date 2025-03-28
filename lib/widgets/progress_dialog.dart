import 'package:flutter/material.dart';

class ProgressDialog extends StatelessWidget {

  String? message;

  ProgressDialog({super.key, this.message});



  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black54,
      child: Container(
        margin: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6)
        ),
        child: Row(
          children: [
            SizedBox(width: 6,),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
            ),
            SizedBox(width: 20.0,),
            Text(
              message!,
              style: TextStyle(
                fontSize: 12,
                color: Colors.black
              ),
            )
          ],
        )
      ),
    );
  }
}

