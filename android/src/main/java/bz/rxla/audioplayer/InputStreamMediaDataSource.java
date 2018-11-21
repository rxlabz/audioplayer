package bz.rxla.audioplayer;

import android.media.MediaDataSource;

import java.io.IOException;
import java.io.InputStream;
import java.lang.reflect.Array;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Collections;
import org.apache.commons.collections4.ListUtils;
import org.apache.commons.lang3.ArrayUtils;
import static java.lang.Math.toIntExact;

public class InputStreamMediaDataSource extends MediaDataSource {
    private InputStream inputStream;
    private List<Byte> loadedData;

    InputStreamMediaDataSource(InputStream inputStream) {
        this.inputStream = inputStream;
        loadedData = new ArrayList<Byte>();
    }

    @Override
    public int readAt(long readStartPosition, byte[] outputBuffer, int outputBufferOffset, int bytesToRead) throws IOException {
        final long readEndPosition = readStartPosition + bytesToRead;
        final int loadedDataEndPosition = loadedData.size() - 1;
        final int numberOfNewBytesToRead = toIntExact(Math.max(readEndPosition - loadedDataEndPosition, 0));
        if (readEndPosition > loadedDataEndPosition) {
            ArrayList<Byte> newlyReadData = readInputStreamToList(inputStream, numberOfNewBytesToRead);
            loadedData = ListUtils.union(loadedData, newlyReadData);
        }
        final List<Byte> readBytesList = loadedData.subList(toIntExact(readStartPosition), toIntExact(readEndPosition));
        final Byte[] readObjectBytesArray = readBytesList.toArray(new Byte[readBytesList.size()]);
        final byte[] readBytesArray = ArrayUtils.toPrimitive(readObjectBytesArray);
        System.arraycopy(readBytesArray, 0, outputBuffer, outputBufferOffset, bytesToRead);
        return bytesToRead;
    }

    private ArrayList<Byte> readInputStreamToList(InputStream inputStream, int numberOfBytesToRead) throws IOException {
        byte[] readBytesArray = new byte[numberOfBytesToRead];
        int numberOfBytesRead = inputStream.read(readBytesArray);  // read the bytes
        if (numberOfBytesRead == -1) {
            throw new IOException("InputStream failed to provide data.");
        } else {
            ArrayList<Byte> outputList = new ArrayList<>(Collections.nCopies(numberOfBytesRead, Byte.valueOf((byte)0)));
            for (int i = 0; i < numberOfBytesRead; i++) {
                outputList.set(i, readBytesArray[i]);
            }
            return outputList;
        }
    }

    public long getSize() {return -1;}

    @Override
    public synchronized void close() throws IOException {

    }
}