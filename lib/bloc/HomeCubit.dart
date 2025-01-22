import 'package:flutter_bloc/flutter_bloc.dart';

class HomeCubit extends Cubit<double> {
    HomeCubit() : super(0);

    void count(){
        emit(state + 1);
    }
}